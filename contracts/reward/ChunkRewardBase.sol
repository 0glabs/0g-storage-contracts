// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/OnlySender.sol";
import "../interfaces/IReward.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Reward.sol";

abstract contract ChunkRewardBase is IReward, PullPayment, OwnableUpgradeable {
    using RewardLibrary for Reward;

    bool public initialized;

    address public market;
    address public mine;

    mapping(uint => Reward) public rewards;

    uint public totalDonations;
    uint public singleDonation;

    uint public serviceFeeRateBps;
    address public treasury;

    function initialize(address market_, address mine_) public initializer {
        __Ownable_init();

        market = market_;
        mine = mine_;

        initialized = true;
    }

    function fillReward(uint beforeLength, uint chargedSectors) external payable {
        require(_msgSender() == market, "Sender does not have permission");

        uint serviceFee = (msg.value * serviceFeeRateBps) / 10000;
        if (serviceFee > 0) {
            Address.sendValue(payable(treasury), serviceFee);
        }
        uint restFee = msg.value - serviceFee;

        uint totalSectors = chargedSectors;
        uint feePerPricingChunk = (restFee * SECTORS_PER_PRICE) / totalSectors;
        uint afterLength = beforeLength + totalSectors;

        uint firstPricingLength = SECTORS_PER_PRICE - (beforeLength % SECTORS_PER_PRICE);
        uint firstPricingIndex = (beforeLength + firstPricingLength) / SECTORS_PER_PRICE - 1;

        uint lastPricingLength = ((afterLength - 1) % SECTORS_PER_PRICE) + 1;
        uint lastPricingIndex = (afterLength - lastPricingLength) / SECTORS_PER_PRICE;

        bool finalizeLastChunk = (afterLength == (lastPricingIndex + 1) * SECTORS_PER_PRICE);

        if (firstPricingIndex == lastPricingIndex) {
            rewards[firstPricingIndex].addReward(msg.value, finalizeLastChunk);
        } else {
            rewards[firstPricingIndex].addReward((feePerPricingChunk * firstPricingLength) / SECTORS_PER_PRICE, true);

            for (uint i = firstPricingIndex + 1; i < lastPricingIndex; i++) {
                rewards[i].addReward(feePerPricingChunk, true);
            }

            rewards[lastPricingIndex].addReward(
                (feePerPricingChunk * lastPricingLength) / SECTORS_PER_PRICE,
                finalizeLastChunk
            );
        }
    }

    function claimMineReward(uint pricingIndex, address payable beneficiary, bytes32) external {
        require(_msgSender() == mine, "Sender does not have permission");

        Reward memory reward = rewards[pricingIndex];

        uint releasedReward = _releasedReward(reward);
        reward.updateReward(releasedReward);
        uint rewardAmount = reward.claimReward();
        rewards[pricingIndex] = reward;

        uint approvedDonation = _donatedReward(pricingIndex, reward, rewardAmount);
        uint actualDonation = totalDonations > approvedDonation ? approvedDonation : totalDonations;
        rewardAmount += actualDonation;
        totalDonations -= actualDonation;

        if (rewardAmount > 0) {
            _asyncTransfer(beneficiary, rewardAmount);
            emit DistributeReward(pricingIndex, beneficiary, rewardAmount);
        }
    }

    function setSingleDonation(uint singleDonation_) external onlyOwner {
        singleDonation = singleDonation_;
    }

    function setServiceFeeRate(uint bps) external onlyOwner {
        serviceFeeRateBps = bps;
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
    }

    function donate() external payable {
        totalDonations += msg.value;
    }

    function _releasedReward(Reward memory reward) internal view virtual returns (uint);

    function _donatedReward(
        uint pricingIndex,
        Reward memory reward,
        uint rewardAmount
    ) internal view virtual returns (uint);
}
