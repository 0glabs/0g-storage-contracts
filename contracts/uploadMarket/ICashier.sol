// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

interface ICashier {
    function chargeFee(uint uploadSectors, uint paddingSectors) external;

    function claimMineReward(uint pricingIndex, address beneficiary) external;

    function getFlowLength() external view returns (uint);
}
