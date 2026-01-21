// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

struct SubmissionNode {
    bytes32 root;
    uint height;
}

struct SubmissionData {
    uint length;
    bytes tags;
    SubmissionNode[] nodes;
}

struct Submission {
    SubmissionData data;
    address submitter;
}

library SubmissionLibrary {
    uint public constant MAX_DEPTH = 64;
    uint public constant ENTRY_SIZE = 256;
    uint public constant MAX_LENGTH = 4;

    function size(Submission memory submission) internal pure returns (uint) {
        SubmissionData memory data = submission.data;
        uint _size = 0;
        for (uint i = 0; i < data.nodes.length; i++) {
            _size += 1 << data.nodes[i].height;
        }
        return _size;
    }

    function valid(Submission memory submission) internal pure returns (bool) {
        if (submission.submitter == address(0)) {
            return false;
        }

        SubmissionData memory data = submission.data;

        if (data.nodes.length == 0) {
            return false;
        }

        // Solidity 0.8 has overflow checking by default.
        if (data.nodes[0].height - data.nodes[data.nodes.length - 1].height >= MAX_LENGTH) {
            return false;
        }

        if (data.nodes[0].height >= MAX_DEPTH) {
            return false;
        }

        for (uint i = 0; i < data.nodes.length - 1; i++) {
            if (data.nodes[i + 1].height >= data.nodes[i].height) {
                return false;
            }
        }

        uint submissionCapacity = size(submission);

        if (data.length > submissionCapacity * ENTRY_SIZE) {
            return false;
        }

        uint lastCapacity;
        if (submissionCapacity < (1 << MAX_LENGTH)) {
            lastCapacity = submissionCapacity - 1;
        } else if (data.nodes.length == 1) {
            lastCapacity = submissionCapacity - (submissionCapacity >> MAX_LENGTH);
        } else {
            lastCapacity = submissionCapacity - (1 << (data.nodes[0].height - MAX_LENGTH + 1));
        }

        if (data.length <= lastCapacity * ENTRY_SIZE) {
            return false;
        }

        return true;
    }

    function digest(Submission memory submission) internal pure returns (bytes32) {
        SubmissionData memory data = submission.data;
        bytes32[] memory hashes = new bytes32[](data.nodes.length);

        for (uint i = 0; i < data.nodes.length; i++) {
            hashes[i] = data.nodes[i].root;
        }

        return keccak256(abi.encodePacked(hashes));
    }
}
