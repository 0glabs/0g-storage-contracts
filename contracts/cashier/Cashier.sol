// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "./token/IUploadToken.sol";
import "../dataFlow/Flow.sol";
import "../utils/ZgsSpec.sol";
import "../utils/Exponent.sol";
import "../utils/OnlySender.sol";
import "../utils/TimeInterval.sol";
import "../token/ISafeERC20.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/AddressBook.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "hardhat/console.sol";

contract Cashier is IMarket, OnlySender, TimeInterval {
    int256 public gauge;
    uint256 public drippingRate;
    uint256 public lastUpdate;

    uint256 public paidUploadAmount;
    uint256 public paidFee;

    uint256 private constant BASIC_PRICE = 1000;
    uint256 private constant UPLOAD_TOKEN_PER_SECTOR = 10**18;

    IReward public immutable reward;
    IUploadToken public immutable uploadToken;
    address public immutable flow;
    address public immutable mine;
    address public immutable stake;

    constructor(
        address book_,
        address uploadToken_,
        address stake_
    ) {
        AddressBook book = AddressBook(book_);
        flow = address(book.flow());
        mine = book.mine();
        reward = book.reward();

        uploadToken = IUploadToken(uploadToken_);
        stake = stake_;

        _tick();
    }

    function refreshGauge() public {
        uint256 timeElapsedInMilliSeconds = _tick();
        uint256 gaugeDelta = (timeElapsedInMilliSeconds * drippingRate) / 1000;
        gauge += int256(gaugeDelta);
        if (gauge > int256(30 * GB)) {
            gauge = int256(30 * GB);
        }
    }

    function _updateDrippingRate(uint256 flowLength) internal {
        refreshGauge();
        drippingRate = Math.min(3 * MB, (flowLength * BYTES_PER_SECTOR) / MB);
    }

    function _topUp(uint256 sectors, uint256 fee) internal {
        paidUploadAmount += sectors;
        paidFee += fee;
    }

    function chargeFee(
        uint256 beforeLength,
        uint256 uploadSectors,
        uint256 paddingSectors
    ) public onlySender(flow) {
        require(
            paidUploadAmount >= uploadSectors,
            "Data submission is not paid"
        );

        uint256 totalSectors = uploadSectors + paddingSectors;
        uint256 afterLength = beforeLength + totalSectors;
        _updateDrippingRate(afterLength);

        uint256 chargedFee = (uploadSectors * paidFee) / paidUploadAmount;
        paidFee -= chargedFee;
        paidUploadAmount -= uploadSectors;

        reward.fillReward{value: chargedFee}(beforeLength, totalSectors);
    }

    function purchase(
        uint256 sectors,
        uint256 maxPrice,
        uint256 maxTipPrice
    ) external payable {
        refreshGauge();
        uint256 purchaseBytes = sectors * BYTES_PER_SECTOR;
        uint256 basicFee = purchaseBytes * BASIC_PRICE;
        uint256 priorFee = computePriorityFee(purchaseBytes);
        uint256 maxTipFee = maxTipPrice * purchaseBytes;
        uint256 maxFee = purchaseBytes * maxPrice;
        require(basicFee + priorFee <= maxFee, "Exceed price limit");

        uint256 actualFee = Math.min(maxFee, basicFee + priorFee + maxTipFee);

        _receiveFee(actualFee, priorFee);

        gauge -= int256(purchaseBytes);

        _topUp(sectors, actualFee - priorFee);
    }

    function _receiveFee(uint256 actualFee, uint256 priorFee) internal virtual {
        uint256 resetBalance = msg.value;

        if (actualFee > priorFee) {
            require(actualFee - priorFee <= resetBalance, "Not enough fee");
            resetBalance -= actualFee - priorFee;
        }

        if (priorFee > 0) {
            require(priorFee <= resetBalance, "Not enough prior fee");
            resetBalance -= priorFee;
            payable(stake).transfer(priorFee);
        }

        if (resetBalance > 0) {
            payable(msg.sender).transfer(resetBalance);
        }
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
}
