// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IReward.sol";
import "../interfaces/AddressBook.sol";
import "../utils/ZgsSpec.sol";
import "../utils/MarketSpec.sol";

import "@openzeppelin/contracts/utils/Context.sol";

contract OnePoolReward is IReward, Context {
    AddressBook public immutable book;
    uint public immutable lifetimeInSeconds;
    TimeoutItem[] public timeoutRecords;
    uint public timeoutHead;

    uint public firstValidChunk; // Inclusive
    uint public lastValidChunk; // Exclusive

    uint public accumulatedReward;
    uint public claimedReward;
    uint public lastUpdateTimestamp;

    uint public nextChunkDonation;
    uint public activeDonation;

    struct TimeoutItem {
        uint64 numPriceChunks;
        uint64 timeoutTimestamp;
        uint donation;
    }

    constructor(address book_, uint lifetimeMonthes) {
        book = AddressBook(book_);
        lifetimeInSeconds = lifetimeMonthes * SECONDS_PER_MONTH;
        lastUpdateTimestamp = block.timestamp;
    }

    function _updateAccumulatedRewardTo(uint timestamp) internal {
        if (timestamp <= lastUpdateTimestamp) {
            return;
        }

        uint reward = ((timestamp - lastUpdateTimestamp) *
            (lastValidChunk - firstValidChunk) *
            BYTES_PER_PRICE *
            ANNUAL_ZGS_TOKENS_PER_GB *
            UNITS_PER_ZGS_TOKEN) /
            GB /
            SECONDS_PER_YEAR;

        uint bonus = (activeDonation * (timestamp - lastUpdateTimestamp)) / lifetimeInSeconds;

        accumulatedReward += reward + bonus;
        lastUpdateTimestamp = timestamp;
    }

    function refresh() public {
        uint length = timeoutRecords.length;

        if (length == 0) {
            lastUpdateTimestamp = block.timestamp;
            _updateAccumulatedRewardTo(block.timestamp);
            return;
        }

        while (timeoutRecords[timeoutHead].timeoutTimestamp <= block.timestamp) {
            _updateAccumulatedRewardTo(timeoutRecords[timeoutHead].timeoutTimestamp);
            firstValidChunk += timeoutRecords[timeoutHead].numPriceChunks;
            activeDonation -= timeoutRecords[timeoutHead].donation;

            // Free storage
            timeoutRecords[timeoutHead] = TimeoutItem({numPriceChunks: 0, timeoutTimestamp: 0, donation: 0});
            timeoutHead += 1;

            if (timeoutHead == length) {
                break;
            }
        }

        _updateAccumulatedRewardTo(block.timestamp);
    }

    function fillReward(uint beforeLength, uint rewardSectors) external payable {
        require(_msgSender() == address(book.market()), "Sender does not have permission");

        refresh();

        uint afterLength = beforeLength + rewardSectors;

        uint beforePriceChunk = beforeLength / SECTORS_PER_PRICE;
        uint afterPriceChunk = afterLength / SECTORS_PER_PRICE;

        if (afterPriceChunk > beforePriceChunk) {
            TimeoutItem memory item = TimeoutItem({
                numPriceChunks: uint64(afterPriceChunk - beforePriceChunk),
                timeoutTimestamp: uint64(block.timestamp + lifetimeInSeconds),
                donation: nextChunkDonation
            });

            timeoutRecords.push(item);

            lastValidChunk = afterPriceChunk;
            activeDonation += nextChunkDonation;
            nextChunkDonation = 0;
        }
    }

    function claimMineReward(uint pricingIndex, address payable beneficiary, bytes32) external {
        require(_msgSender() == address(book.mine()), "Sender does not have permission");

        if (pricingIndex < firstValidChunk) {
            // The target price chunk is not open for mine
            return;
        }

        refresh();

        uint claimable = accumulatedReward - claimedReward;
        if (claimable > address(this).balance) {
            claimable = address(this).balance;
        }

        if (claimable > 0) {
            beneficiary.transfer(claimable);
            emit DistributeReward(pricingIndex, beneficiary, claimable);
        }
    }

    receive() external payable {
        nextChunkDonation += msg.value;
    }
}
