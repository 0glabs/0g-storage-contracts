// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";

contract DummyReward is IReward {
    function fillReward(uint beforeLength, uint uploadSectors) external payable {}

    function claimMineReward(uint pricingIndex, address payable beneficiary, bytes32 minerId) external {}
}
