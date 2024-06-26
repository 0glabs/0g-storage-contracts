// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../miner/Mine.sol";

contract PoraMineTest is PoraMine {
    // 1, 1, settings | 0x4
    constructor(uint settings) PoraMine(settings | 0x4) {}

    function setMiner(bytes32 minerId) external {
        beneficiaries[minerId] = msg.sender;
    }

    function setQuality(uint _targetQuality) external {
        targetQuality = _targetQuality;
    }
}
