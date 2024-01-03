// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "./ICashier.sol";
import "../token/IUploadToken.sol";
import "../dataFlow/Flow.sol";
import "../utils/ZgsSpec.sol";
import "../utils/Exponent.sol";
import "../utils/OnlySender.sol";
import "../utils/TimeInterval.sol";
import "../token/ISafeERC20.sol";
import "./Reward.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "hardhat/console.sol";

contract Cashier is ICashier, OnlySender, TimeInterval {
    using RewardLibrary for Reward;
    int256 public gauge;
    uint256 public drippingRate;
    uint256 public lastUpdate;
    uint256 public flowLength;

    uint256 public paidUploadAmount;
    uint256 public paidFee;

    mapping(uint256 => Reward) public rewards;

    uint256 private constant BASIC_PRICE = 1000;
    uint256 private constant UPLOAD_TOKEN_PER_SECTOR = 10**18;

    ISafeERC20 public immutable zgsToken;
    IUploadToken public immutable uploadToken;
    address public immutable flow;
    address public immutable mine;
    address public immutable stake;

    constructor(
        address zgsToken_,
        address uploadToken_,
        address flow_,
        address mine_,
        address stake_
    ) {
        zgsToken = ISafeERC20(zgsToken_);
        uploadToken = IUploadToken(uploadToken_);
        flow = flow_;
        mine = mine_;
        stake = stake_;
        flowLength = 1;

        _tick();
    }

    function updateGauge() public {
        uint256 timeElapsedInMilliSeconds = _tick();
        uint256 gaugeDelta = (timeElapsedInMilliSeconds * drippingRate) / 1000;
        gauge += int256(gaugeDelta);
        if (gauge > int256(30 * GB)) {
            gauge = int256(30 * GB);
        }
    }

    function _updateTotalSubmission(uint256 sectors) internal {
        updateGauge();
        flowLength += sectors;
        drippingRate = Math.min(3 * MB, (flowLength * BYTES_PER_SECTOR) / MB);
    }

    function _topUp(uint256 sectors, uint256 fee) internal {
        paidUploadAmount += sectors;
        paidFee += fee;
    }

    function chargeFee(uint256 uploadSectors, uint256 paddingSectors)
        external
        onlySender(flow)
    {
        require(
            paidUploadAmount >= uploadSectors,
            "Data submission is not paid"
        );

        uint256 totalSectors = uploadSectors + paddingSectors;

        uint256 beforeLength = flowLength;
        _updateTotalSubmission(totalSectors);
        uint256 afterLength = flowLength;

        uint256 chargedFee = (uploadSectors * paidFee) / paidUploadAmount;
        paidFee -= chargedFee;
        paidUploadAmount -= uploadSectors;

        uint256 feePerPricingChunk = (chargedFee * SECTORS_PER_PRICE) /
            totalSectors;

        uint256 firstPricingLength = SECTORS_PER_PRICE -
            (beforeLength % SECTORS_PER_PRICE);
        uint256 firstPricingIndex = (beforeLength + firstPricingLength) /
            SECTORS_PER_PRICE -
            1;

        uint256 lastPricingLength = ((afterLength - 1) % SECTORS_PER_PRICE) + 1;
        uint256 lastPricingIndex = (afterLength - lastPricingLength) /
            SECTORS_PER_PRICE;

        bool finalizeLastChunk = (afterLength ==
            (lastPricingIndex + 1) * SECTORS_PER_PRICE);

        if (firstPricingIndex == lastPricingIndex) {
            rewards[firstPricingIndex].addReward(
                (feePerPricingChunk * (afterLength - beforeLength)) /
                    SECTORS_PER_PRICE,
                finalizeLastChunk
            );
        } else {
            rewards[firstPricingIndex].addReward(
                (feePerPricingChunk * firstPricingLength) / SECTORS_PER_PRICE,
                true
            );
            rewards[lastPricingIndex].addReward(
                (feePerPricingChunk * lastPricingLength) / SECTORS_PER_PRICE,
                finalizeLastChunk
            );

            for (uint256 i = firstPricingIndex + 1; i < lastPricingIndex; i++) {
                rewards[i].addReward(feePerPricingChunk, true);
            }
        }
    }

    function claimMineReward(uint256 pricingIndex, address beneficiary)
        external
        onlySender(mine)
    {
        uint256 rewardAmount = rewards[pricingIndex].claimReward();
        zgsToken.transfer(beneficiary, rewardAmount);
    }

    function purchase(
        uint256 sectors,
        uint256 maxPrice,
        uint256 maxTipPrice
    ) external {
        updateGauge();
        uint256 purchaseBytes = sectors * BYTES_PER_SECTOR;
        uint256 basicFee = purchaseBytes * BASIC_PRICE;
        uint256 priorFee = computePriorityFee(purchaseBytes);
        uint256 maxTipFee = maxTipPrice * purchaseBytes;
        uint256 maxFee = purchaseBytes * maxPrice;
        require(basicFee + priorFee <= maxFee, "Exceed price limit");

        uint256 actualFee = Math.min(maxFee, basicFee + priorFee + maxTipFee);

        if (actualFee > priorFee) {
            zgsToken.transferFrom(
                msg.sender,
                address(this),
                actualFee - priorFee
            );
        }
        if (priorFee > 0) {
            zgsToken.transferFrom(msg.sender, stake, priorFee);
        }

        gauge -= int256(purchaseBytes);

        _topUp(sectors, actualFee - priorFee);
    }

    function consumeUploadToken(uint256 sectors) external {
        uint256 consumedTokens = sectors * UPLOAD_TOKEN_PER_SECTOR;

        uploadToken.consume(msg.sender, consumedTokens);

        _topUp(sectors, sectors * BYTES_PER_SECTOR * BASIC_PRICE);
    }

    function computePriorityFee(uint256 purchaseBytes)
        public
        view
        returns (uint256)
    {
        uint256 chargeStart;
        uint256 chargeEnd;
        if (gauge >= 0) {
            uint256 _gauge = uint256(gauge);
            if (_gauge >= purchaseBytes) {
                return 0;
            } else {
                chargeStart = 0;
                chargeEnd = purchaseBytes - _gauge;
            }
        } else {
            uint256 _gauge = uint256(-gauge);
            chargeStart = _gauge;
            chargeEnd = _gauge + purchaseBytes;
        }

        require(chargeEnd <= 100 * GB, "Gauge underflow");

        uint256 aX64 = (chargeStart << 64) / (900 * MB);
        uint256 bX64 = (chargeEnd << 64) / (900 * MB);
        uint256 answerFactor1X96 = Exponential.powTwo64X96(bX64 - aX64) -
            (1 << 96);
        uint256 answerFactor2X96 = Exponential.powTwo64X96(aX64);
        uint256 answerX128;
        if (answerFactor2X96 > 1 << 104) {
            answerX128 = answerFactor1X96 * (answerFactor2X96 >> 64);
        } else if (answerFactor1X96 > 1 << 104) {
            answerX128 = (answerFactor1X96 >> 64) * answerFactor2X96;
        } else {
            answerX128 = (answerFactor1X96 * answerFactor2X96) >> 64;
        }
        uint256 answerX96 = answerX128 >> 32;
        return ((answerX96 * BASIC_PRICE * (900 * MB)) / 100) >> 96;
    }

    function getFlowLength() external view returns (uint256) {
        return flowLength;
    }
}
