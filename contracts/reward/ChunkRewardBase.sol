// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/OnlySender.sol";
import "../interfaces/IReward.sol";
import "../interfaces/AddressBook.sol";

import "./Reward.sol";

abstract contract ChunkRewardBase is IReward, OnlySender {
    using RewardLibrary for Reward;

    mapping(uint => Reward) public rewards;
    AddressBook public immutable book;

    constructor(address _book) {
        book = AddressBook(_book);
    }

    function fillReward(uint beforeLength, uint chargedSectors) external payable {
        require(_msgSender() == address(book.market()), "Sender does not have permission");

        uint totalSectors = chargedSectors;
        uint feePerPricingChunk = (msg.value * SECTORS_PER_PRICE) / totalSectors;
        uint afterLength = beforeLength + totalSectors;

        uint firstPricingLength = SECTORS_PER_PRICE - (beforeLength % SECTORS_PER_PRICE);
        uint firstPricingIndex = (beforeLength + firstPricingLength) / SECTORS_PER_PRICE - 1;

        uint lastPricingLength = ((afterLength - 1) % SECTORS_PER_PRICE) + 1;
        uint lastPricingIndex = (afterLength - lastPricingLength) / SECTORS_PER_PRICE;

        bool finalizeLastChunk = (afterLength == (lastPricingIndex + 1) * SECTORS_PER_PRICE);

        if (firstPricingIndex == lastPricingIndex) {
            rewards[firstPricingIndex].addReward(
                (feePerPricingChunk * (afterLength - beforeLength)) / SECTORS_PER_PRICE,
                finalizeLastChunk
            );
        } else {
            rewards[firstPricingIndex].addReward((feePerPricingChunk * firstPricingLength) / SECTORS_PER_PRICE, true);
            rewards[lastPricingIndex].addReward(
                (feePerPricingChunk * lastPricingLength) / SECTORS_PER_PRICE,
                finalizeLastChunk
            );

            for (uint i = firstPricingIndex + 1; i < lastPricingIndex; i++) {
                rewards[i].addReward(feePerPricingChunk, true);
            }
        }
    }

    function claimMineReward(uint pricingIndex, address payable beneficiary, bytes32) external {
        require(_msgSender() == book.mine(), "Sender does not have permission");

        Reward memory reward = rewards[pricingIndex];

        uint releasedReward = _releasedReward(reward);
        reward.updateReward(releasedReward);
        uint rewardAmount = reward.claimReward();

        rewards[pricingIndex] = reward;

        if (rewardAmount > 0) {
            beneficiary.transfer(rewardAmount);
            emit DistributeReward(pricingIndex, beneficiary, rewardAmount);
        }
    }

    function _releasedReward(Reward memory reward) internal virtual returns (uint);
}
