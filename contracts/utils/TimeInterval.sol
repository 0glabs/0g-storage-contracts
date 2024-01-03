// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

contract TimeInterval{
    uint256 private lastTimestamp;

    function _tick() internal returns(uint256 timeElapsed) {
        timeElapsed = block.timestamp - lastTimestamp;
        lastTimestamp = block.timestamp;
        unchecked { timeElapsed *= 1000; }
    }
}