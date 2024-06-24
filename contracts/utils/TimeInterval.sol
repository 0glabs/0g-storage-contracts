// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

contract TimeInterval {
    uint private lastTimestamp;

    function _tick() internal returns (uint timeElapsed) {
        timeElapsed = block.timestamp - lastTimestamp;
        lastTimestamp = block.timestamp;
        unchecked {
            timeElapsed *= 1000;
        }
    }
}
