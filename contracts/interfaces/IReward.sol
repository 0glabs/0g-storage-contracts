// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

interface IReward {
    event DistributeReward(
        uint indexed pricingIndex,
        address indexed beneficiary,
        bytes32 indexed minerId,
        uint amount
    );

    function fillReward(uint beforeLength, uint rewardSectors) external payable;

    function claimMineReward(uint pricingIndex, address payable beneficiary, bytes32 minerId) external;
}
