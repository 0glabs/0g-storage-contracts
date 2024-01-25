// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

interface ICashier {
    function chargeFee(uint256 uploadSectors, uint256 paddingSectors) external;

    function claimMineReward(uint256 pricingIndex, address beneficiary)
        external;

    function getFlowLength() external view returns (uint256);
}
