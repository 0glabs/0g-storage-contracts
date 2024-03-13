// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./Submission.sol";

struct EpochRange {
    uint128 start;
    uint128 end;
}

struct EpochRangeWithContextDigest {
    uint128 start;
    uint128 end;
    bytes32 digest;
}

struct MineContext {
    uint256 epoch;
    uint256 mineStart;
    bytes32 flowRoot;
    uint256 flowLength;
    bytes32 blockDigest;
    bytes32 digest;
}

interface IFlow {
    event Submit(
        address indexed sender,
        bytes32 indexed identity,
        uint256 submissionIndex,
        uint256 startPos,
        uint256 length,
        Submission submission
    );

    event NewEpoch(
        address indexed sender,
        uint256 indexed index,
        bytes32 startMerkleRoot,
        uint256 submissionIndex,
        uint256 flowLength,
        bytes32 context
    );

    function batchSubmit(Submission[] memory submissions)
        external
        payable
        returns (
            uint256[] memory indexes,
            bytes32[] memory digests,
            uint256[] memory startIndexes,
            uint256[] memory lengths
        );

    function submit(Submission memory submission)
        external
        payable
        returns (
            uint256,
            bytes32,
            uint256,
            uint256
        );

    function makeContext() external;

    function getContext() external view returns (MineContext memory);

    function getEpochRange(bytes32 digest)
        external
        view
        returns (EpochRange memory);

    function numSubmissions() external view returns (uint256);
}
