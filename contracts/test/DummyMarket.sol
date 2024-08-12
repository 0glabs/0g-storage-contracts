// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";

contract DummyMarket {
    function chargeFee(uint beforeLength, uint uploadSectors, uint paddingSectors) external {}

    function pricePerSector() external pure returns (uint) {
        return 0;
    }
}
