// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "./Reward.sol";
import "./ChunkRewardBase.sol";
import "../utils/ZgsSpec.sol";
import "../utils/MarketSpec.sol";
import "../utils/Initializable.sol";

contract ChunkLinearReward is Initializable, ChunkRewardBase {
    using RewardLibrary for Reward;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    uint16 public immutable releaseMonths;

    constructor(uint16 releaseMonths_) {
        releaseMonths = releaseMonths_;
    }

    function _releasedReward(Reward memory reward) internal view override returns (uint) {
        return reward.linearDecayReward(releaseMonths);
    }

    function _donatedReward(uint, Reward memory reward, uint) internal view override returns (uint) {
        uint releaseSeconds = releaseMonths * SECONDS_PER_MONTH;
        if (reward.startTime + releaseSeconds <= block.timestamp) {
            return singleDonation;
        } else {
            return 0;
        }
    }

    function rewardDeadline(uint pricingIndex) public view returns (uint) {
        uint releaseSeconds = releaseMonths * SECONDS_PER_MONTH;
        Reward memory reward = rewards[pricingIndex];
        if (reward.startTime == 0) {
            return 0;
        }
        return reward.startTime + releaseSeconds;
    }

    function _deadlinePassed(uint pricingIndex) internal view returns (bool) {
        uint deadline = rewardDeadline(pricingIndex);
        return deadline != 0 && deadline < block.timestamp;
    }

    function firstRewardableChunk() public view returns (uint64) {
        uint64 low = 0;
        uint64 high = 1024;

        while (_deadlinePassed(high)) {
            low = high;
            high *= 2;
        }

        while (low < high) {
            uint64 mid = low + (high - low) / 2;
            if (_deadlinePassed(mid)) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        return low;
    }
}
