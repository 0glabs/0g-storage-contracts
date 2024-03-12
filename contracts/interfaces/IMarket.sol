// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

interface IMarket {
    function chargeFee(uint256 uploadSectors, uint256 paddingSectors) external;
}
