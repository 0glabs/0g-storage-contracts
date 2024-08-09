// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/ZgInitializable.sol";
import "../utils/OnlySender.sol";
import "../interfaces/IReward.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "./Reward.sol";
import "../utils/PullPayment.sol";

abstract contract ChunkRewardBase is IReward, PullPayment, ZgInitializable, AccessControlEnumerable {
    using RewardLibrary for Reward;

    bytes32 public constant PARAMS_ADMIN_ROLE = keccak256("PARAMS_ADMIN_ROLE");

    address public market;
    address public mine;

    mapping(uint => Reward) public rewards;

    uint public totalBaseReward;
    uint public baseReward;

    uint public serviceFeeRateBps;
    address public treasury;

    function initialize(address market_, address mine_) public onlyInitializeOnce {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PARAMS_ADMIN_ROLE, _msgSender());

        market = market_;
        mine = mine_;

        // deploy pullpayment escrow
        _escrow = new Escrow();
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
            rewards[firstPricingIndex].addReward(restFee, finalizeLastChunk);
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

        uint approvedReward = _baseReward(pricingIndex, reward, rewardAmount);
        uint actualBaseReward = totalBaseReward > approvedReward ? approvedReward : totalBaseReward;
        rewardAmount += actualBaseReward;
        totalBaseReward -= actualBaseReward;

        if (rewardAmount > 0) {
            _asyncTransfer(beneficiary, rewardAmount);
            emit DistributeReward(pricingIndex, beneficiary, rewardAmount);
        }
    }

    function setBaseReward(uint baseReward_) external onlyRole(PARAMS_ADMIN_ROLE) {
        baseReward = baseReward_;
    }

    function setServiceFeeRate(uint bps) external onlyRole(PARAMS_ADMIN_ROLE) {
        serviceFeeRateBps = bps;
    }

    function setTreasury(address treasury_) external onlyRole(PARAMS_ADMIN_ROLE) {
        treasury = treasury_;
    }

    function donate() external payable {
        totalBaseReward += msg.value;
    }

    function _releasedReward(Reward memory reward) internal view virtual returns (uint);

    function _baseReward(
        uint pricingIndex,
        Reward memory reward,
        uint rewardAmount
    ) internal view virtual returns (uint);
}
