// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IReward.sol";
import "../interfaces/AddressBook.sol";
import "../utils/ZgsSpec.sol";
import "../utils/MarketSpec.sol";

import "@openzeppelin/contracts/utils/Context.sol";

contract OnePoolReward is IReward, Context {
    AddressBook public immutable book;
    uint256 public immutable lifetimeSeconds;
    TimeoutItem[] public timeoutRecords;
    uint256 public timeoutHead;

    uint256 public firstValidChunk; // Inclusive
    uint256 public lastValidChunk; // Exclusive

    uint256 public accumulatedReward;
    uint256 public claimedReward;
    uint256 public lastUpdateTimestamp;

    struct TimeoutItem {
        uint64 numPriceChunks;
        uint64 timeoutTimestamp;
    }

    constructor(address book_, uint256 lifetimeMonthes) {
        book = AddressBook(book_);
        lifetimeSeconds = lifetimeMonthes * SECONDS_PER_MONTH;
        lastUpdateTimestamp = block.timestamp;
    }

    function _updateAccumulatedRewardTo(uint256 timestamp) internal {
        if (timestamp <= lastUpdateTimestamp) {
            return;
        }

        uint256 reward = ((timestamp - lastUpdateTimestamp) *
            (lastValidChunk - firstValidChunk) *
            BYTES_PER_PRICE *
            ANNUAL_ZGS_TOKENS_PER_GB *
            UNITS_PER_ZGS_TOKEN) /
            GB /
            SECONDS_PER_YEAR;

        accumulatedReward += reward;
        lastUpdateTimestamp = timestamp;
    }

    function refresh() public {
        uint256 length = timeoutRecords.length;

        if (length == 0) {
            lastUpdateTimestamp = block.timestamp;
            _updateAccumulatedRewardTo(block.timestamp);
            return;
        }

        while (
            timeoutRecords[timeoutHead].timeoutTimestamp <= block.timestamp
        ) {
            _updateAccumulatedRewardTo(
                timeoutRecords[timeoutHead].timeoutTimestamp
            );
            firstValidChunk += timeoutRecords[timeoutHead].numPriceChunks;

            // Free storage
            timeoutRecords[timeoutHead] = TimeoutItem({
                numPriceChunks: 0,
                timeoutTimestamp: 0
            });
            timeoutHead += 1;

            if (timeoutHead == length) {
                break;
            }
        }

        _updateAccumulatedRewardTo(block.timestamp);
    }

    function fillReward(uint256 beforeLength, uint256 rewardSectors)
        external
        payable
    {
        require(
            _msgSender() == address(book.market()),
            "Sender does not have permission"
        );

        refresh();

        uint256 afterLength = beforeLength + rewardSectors;

        uint256 beforePriceChunk = beforeLength / SECTORS_PER_PRICE;
        uint256 afterPriceChunk = afterLength / SECTORS_PER_PRICE;

        if (afterPriceChunk > beforePriceChunk) {
            TimeoutItem memory item = TimeoutItem({
                numPriceChunks: uint64(afterPriceChunk - beforePriceChunk),
                timeoutTimestamp: uint64(block.timestamp + lifetimeSeconds)
            });
            timeoutRecords.push(item);

            lastValidChunk = afterPriceChunk;
        }
    }

    function claimMineReward(uint256 pricingIndex, address payable beneficiary)
        external
    {
        require(
            _msgSender() == address(book.mine()),
            "Sender does not have permission"
        );

        if (pricingIndex < firstValidChunk) {
            // The target price chunk is not open for mine
            return;
        }

        refresh();

        uint256 claimable = accumulatedReward - claimedReward;
        if (claimable > address(this).balance) {
            claimable = address(this).balance;
        }

        if (claimable > 0) {
            beneficiary.transfer(claimable);
            emit DistributeReward(pricingIndex, beneficiary, claimable);
        }
    }
}
