// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

struct SubmissionNode {
    bytes32 root;
    uint256 height;
}

struct Submission {
    uint256 length;
    bytes tags;
    SubmissionNode[] nodes;
}

library SubmissionLibrary {
    uint256 constant MAX_DEPTH = 64;
    uint256 constant ENTRY_SIZE = 256;
    uint256 constant MAX_LENGTH = 4;

    function size(Submission memory submission)
        internal
        pure
        returns (uint256)
    {
        uint256 _size = 0;
        for (uint256 i = 0; i < submission.nodes.length; i++) {
            _size += 1 << submission.nodes[i].height;
        }
        return _size;
    }

    function valid(Submission memory submission)
        internal
        pure
        returns (bool)
    {
        if (submission.nodes.length == 0) {
            return false;
        }

        // Solidity 0.8 has overflow checking by default.
        if (
            submission.nodes[0].height -
                submission.nodes[submission.nodes.length - 1].height >=
            MAX_LENGTH
        ) {
            return false;
        }

        if (submission.nodes[0].height >= MAX_DEPTH) {
            return false;
        }

        for (uint256 i = 0; i < submission.nodes.length - 1; i++) {
            if (submission.nodes[i + 1].height >= submission.nodes[i].height) {
                return false;
            }
        }

        uint256 submissionCapacity = size(submission);

        if (submission.length > submissionCapacity * ENTRY_SIZE) {
            return false;
        }

        uint256 lastCapacity;
        if (submissionCapacity < (1 << MAX_LENGTH)) {
            lastCapacity = submissionCapacity - 1;
        } else if (submission.nodes.length == 1) {
            lastCapacity =
                submissionCapacity -
                (submissionCapacity >> MAX_LENGTH);
        } else {
            lastCapacity =
                submissionCapacity -
                (1 << (submission.nodes[0].height - MAX_LENGTH + 1));
        }

        if (submission.length <= lastCapacity * ENTRY_SIZE) {
            return false;
        }

        return true;
    }

    function digest(Submission memory submission)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(submission.nodes));
    }
}
