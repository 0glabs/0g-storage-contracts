// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../miner/Mine.sol";

contract PoraMineTest is PoraMine {
    constructor(
        address flow,
        address cashier,
        uint256 settings
    ) PoraMine(flow, cashier, settings) {}

    function setMiner(bytes32 minerId) external {
        minerIds[msg.sender] = minerId;
    }

    function setQuality(uint256 _targetQuality) external {
        targetQuality = _targetQuality;
    }
}
