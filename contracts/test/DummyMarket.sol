// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";

contract DummyMarket is IMarket {
    function chargeFee(uint beforeLength, uint uploadSectors, uint paddingSectors) external {}
}
