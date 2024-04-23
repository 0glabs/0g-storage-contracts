// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

interface IReward {
    event DistributeReward(
        uint256 indexed pricingIndex,
        address indexed beneficiary,
        uint256 amount
    );

    function fillReward(uint256 beforeLength, uint256 rewardSectors)
        external
        payable;

    function claimMineReward(uint256 pricingIndex, address payable beneficiary, bytes32 minerId)
        external;
}
