// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../miner/Mine.sol";

contract PoraMineTest is PoraMine {
    constructor(address book, uint256 settings)
        PoraMine(book, 1, 1, settings | 0x4)
    {}

    function setMiner(bytes32 minerId) external {
        beneficiaries[minerId] = msg.sender;
    }

    function setQuality(uint256 _targetQuality) external {
        targetQuality = _targetQuality;
    }
}
