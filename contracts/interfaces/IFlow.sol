// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./Submission.sol";
import "./IDigestHistory.sol";

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

    function blocksPerEpoch() external view returns (uint);

    function epoch() external view returns (uint);

    function epochStartPosition() external view returns (uint);

    function firstBlock() external view returns (uint);

    function getContext() external view returns (MineContext memory);

    function getEpochRange(bytes32 digest) external view returns (EpochRange memory);

    function getFlowRootByTxSeq(uint txSeq) external view returns (bytes32);

    function makeContext() external;

    function makeContextFixedTimes(uint cnt) external;

    function makeContextWithResult() external returns (MineContext memory);

    function market() external view returns (address payable);

    function numSubmissions() external view returns (uint);

    function queryContextAtPosition(uint128 targetPosition) external returns (EpochRangeWithContextDigest memory range);

    function rootHistory() external view returns (IDigestHistory);

    function submissionIndex() external view returns (uint);

    function submit(Submission memory submission) external payable returns (uint, bytes32, uint, uint);

    function tree() external view returns (uint currentLength, uint unstagedHeight);
}
