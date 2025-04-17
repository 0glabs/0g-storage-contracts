// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/OnlySender.sol";
import "../interfaces/IReward.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./Reward.sol";
import "../utils/PullPayment.sol";

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

abstract contract ChunkRewardBase is IReward, PullPayment, AccessControlEnumerableUpgradeable {
    using RewardLibrary for Reward;

    bytes32 public constant PARAMS_ADMIN_ROLE = keccak256("PARAMS_ADMIN_ROLE");

    /// @custom:storage-location erc7201:0g.storage.ChunkRewardBase
    struct ChunkRewardBaseStorage {
        address market;
        address mine;
        mapping(uint => Reward) rewards;
        uint totalBaseReward;
        uint baseReward;
        uint serviceFeeRateBps;
        address treasury;
    }

    // keccak256(abi.encode(uint(keccak256("0g.storage.ChunkRewardBase")) - 1)) & ~bytes32(uint(0xff))
    bytes32 private constant ChunkRewardBaseStorageLocation =
        0x5c8dfb41bf775ed78439bdc545dd2d846bd8da274c69de26cd754e645898d800;

    function _getChunkRewardBaseStorage() private pure returns (ChunkRewardBaseStorage storage $) {
        assembly {
            $.slot := ChunkRewardBaseStorageLocation
        }
    }

    function initialize(address market_, address mine_) public initializer {
        ChunkRewardBaseStorage storage $ = _getChunkRewardBaseStorage();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PARAMS_ADMIN_ROLE, _msgSender());

        $.market = market_;
        $.mine = mine_;

        // deploy pullpayment escrow
        __PullPayment_init();
    }

    /*=== view ===*/

    function market() public view returns (address) {
        return _getChunkRewardBaseStorage().market;
    }

    function mine() public view returns (address) {
        return _getChunkRewardBaseStorage().mine;
    }

    function rewards(uint id) public view returns (Reward memory) {
        return _getChunkRewardBaseStorage().rewards[id];
    }

    function totalBaseReward() public view returns (uint) {
        return _getChunkRewardBaseStorage().totalBaseReward;
    }

    function baseReward() public view returns (uint) {
        return _getChunkRewardBaseStorage().baseReward;
    }

    function serviceFeeRateBps() public view returns (uint) {
        return _getChunkRewardBaseStorage().serviceFeeRateBps;
    }

    function treasury() public view returns (address) {
        return _getChunkRewardBaseStorage().treasury;
    }

    /*=== main ===*/

    function fillReward(uint beforeLength, uint chargedSectors) external payable {
        ChunkRewardBaseStorage storage $ = _getChunkRewardBaseStorage();

        require(_msgSender() == $.market, "Sender does not have permission");

        uint serviceFee = (msg.value * $.serviceFeeRateBps) / 10000;
        if (serviceFee > 0) {
            Address.sendValue(payable($.treasury), serviceFee);
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
            $.rewards[firstPricingIndex].addReward(restFee, finalizeLastChunk);
        } else {
            $.rewards[firstPricingIndex].addReward((feePerPricingChunk * firstPricingLength) / SECTORS_PER_PRICE, true);

            for (uint i = firstPricingIndex + 1; i < lastPricingIndex; i++) {
                $.rewards[i].addReward(feePerPricingChunk, true);
            }

            $.rewards[lastPricingIndex].addReward(
                (feePerPricingChunk * lastPricingLength) / SECTORS_PER_PRICE,
                finalizeLastChunk
            );
        }
    }

    function claimMineReward(uint pricingIndex, address payable beneficiary, bytes32 minerID) external {
        ChunkRewardBaseStorage storage $ = _getChunkRewardBaseStorage();
        require(_msgSender() == $.mine, "Sender does not have permission");

        Reward memory reward = $.rewards[pricingIndex];

        uint releasedReward = _releasedReward(reward);
        reward.updateReward(releasedReward);
        uint rewardAmount = reward.claimReward();
        $.rewards[pricingIndex] = reward;

        uint approvedBaseReward = _baseReward(pricingIndex, reward, rewardAmount);
        uint actualBaseReward = $.totalBaseReward > approvedBaseReward ? approvedBaseReward : $.totalBaseReward;
        rewardAmount += actualBaseReward;
        $.totalBaseReward -= actualBaseReward;

        if (rewardAmount > 0) {
            _asyncTransfer(beneficiary, rewardAmount);
            emit DistributeReward(pricingIndex, beneficiary, minerID, rewardAmount);
        }
    }

    function setBaseReward(uint baseReward_) external onlyRole(PARAMS_ADMIN_ROLE) {
        ChunkRewardBaseStorage storage $ = _getChunkRewardBaseStorage();
        $.baseReward = baseReward_;
    }

    function setServiceFeeRate(uint bps) external onlyRole(PARAMS_ADMIN_ROLE) {
        ChunkRewardBaseStorage storage $ = _getChunkRewardBaseStorage();
        $.serviceFeeRateBps = bps;
    }

    function setTreasury(address treasury_) external onlyRole(PARAMS_ADMIN_ROLE) {
        ChunkRewardBaseStorage storage $ = _getChunkRewardBaseStorage();
        $.treasury = treasury_;
    }

    function donate() external payable {
        ChunkRewardBaseStorage storage $ = _getChunkRewardBaseStorage();
        $.totalBaseReward += msg.value;
    }

    function _releasedReward(Reward memory reward) internal view virtual returns (uint);

    function _baseReward(
        uint pricingIndex,
        Reward memory reward,
        uint rewardAmount
    ) internal view virtual returns (uint);
}
