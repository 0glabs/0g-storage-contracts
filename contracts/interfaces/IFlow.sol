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
    uint epoch;
    uint mineStart;
    bytes32 flowRoot;
    uint flowLength;
    bytes32 blockDigest;
    bytes32 digest;
}

interface IFlow {
    event Submit(
        address indexed sender,
        bytes32 indexed identity,
        uint submissionIndex,
        uint startPos,
        uint length,
        Submission submission
    );

    event NewEpoch(
        address indexed sender,
        uint indexed index,
        bytes32 startMerkleRoot,
        uint submissionIndex,
        uint flowLength,
        bytes32 context
    );

    function batchSubmit(
        Submission[] memory submissions
    )
        external
        payable
        returns (uint[] memory indexes, bytes32[] memory digests, uint[] memory startIndexes, uint[] memory lengths);

    function submit(Submission memory submission) external payable returns (uint, bytes32, uint, uint);

    function makeContext() external;

    function makeContextWithResult() external returns (MineContext memory);

    function getContext() external view returns (MineContext memory);

    function getEpochRange(bytes32 digest) external view returns (EpochRange memory);

    function numSubmissions() external view returns (uint);
}
