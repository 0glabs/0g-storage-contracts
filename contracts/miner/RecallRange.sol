// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../utils/ZgsSpec.sol";

struct RecallRange {
    uint256 startPosition;
    uint256 mineLength;
    uint64 shardId;
    uint64 shardMask;
}

library RecallRangeLib {
    using RecallRangeLib for RecallRange;

    function check(RecallRange memory range, uint256 maxEndPosition)
        internal
        pure
    {
        require(
            range.startPosition % SECTORS_PER_PRICE == 0,
            "Start position is not aligned"
        );

        require(
            range.startPosition + range.mineLength <= maxEndPosition,
            "Mining range overflow"
        );

        uint256 maxMineLength = MAX_MINING_LENGTH * range.numShards();
        require(range.mineLength <= maxMineLength, "Mining range too long");

        uint256 requiredLength = Math.min(maxEndPosition, maxMineLength);
        require(range.mineLength >= requiredLength, "Mining range too short");

        require(
            range.shardId & range.shardMask == 0,
            "Masked bits should be zero"
        );
    }

    // Compute bit `1` in shardMask, while assuming there is only a few zeros.
    function numShards(RecallRange memory range)
        internal
        pure
        returns (uint256)
    {
        uint64 negMask = ~range.shardMask;
        uint8 answer = 0;
        while (negMask > 0) {
            negMask &= negMask - 1;
            answer++;
        }
        return 1 << answer;
    }

    function digest(RecallRange memory range) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    range.startPosition,
                    range.mineLength,
                    range.shardId,
                    range.shardMask
                )
            );
    }

    function recallChunk(RecallRange memory range, bytes32 seed)
        internal
        pure
        returns (uint256)
    {
        uint256 originChunkOffset = uint256(seed) %
            (range.mineLength / SECTORS_PER_LOAD);
        uint64 chunkOffset = (uint64(originChunkOffset) & range.shardMask) |
            range.shardId;

        require(
            chunkOffset * SECTORS_PER_LOAD <= range.mineLength,
            "Recall position out of bound"
        );

        return range.startPosition + chunkOffset * SECTORS_PER_LOAD;
    }
}
