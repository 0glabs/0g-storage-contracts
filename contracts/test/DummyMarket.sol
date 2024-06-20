// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";

contract DummyMarket is IMarket {
    function chargeFee(
        uint256 beforeLength,
        uint256 uploadSectors,
        uint256 paddingSectors
    ) external {}
}