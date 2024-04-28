// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../utils/ZgsSpec.sol";

struct RecallRange {
    uint256 startPosition;
    uint256 mineLength;
}

library RecallRangeLib {
    function check(RecallRange memory range, uint256 maxLength) internal pure {
        require(
            range.startPosition + range.mineLength <= maxLength,
            "Mining range overflow"
        );
        require(range.mineLength <= MAX_MINING_LENGTH, "Mining range too long");

        require(
            range.startPosition % SECTORS_PER_PRICE == 0,
            "Start position is not aligned"
        );

        uint256 requiredLength = Math.min(maxLength, MAX_MINING_LENGTH);

        require(range.mineLength >= requiredLength, "Mining range too short");
    }

    function recallChunk(RecallRange memory range, bytes32 seed)
        internal
        pure
        returns (uint256)
    {
        uint256 chunkOffset = uint256(seed) %
            (range.mineLength / SECTORS_PER_LOAD);

        return range.startPosition + chunkOffset * SECTORS_PER_LOAD;
    }
}
