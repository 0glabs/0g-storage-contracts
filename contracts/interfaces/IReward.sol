// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

interface IReward {
    function fillReward(uint256 beforeLength, uint256 uploadSectors)
        external
        payable;

    function claimMineReward(uint256 pricingIndex, address payable beneficiary)
        external;
}
