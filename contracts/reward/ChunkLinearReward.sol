// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "./Reward.sol";
import "./ChunkRewardBase.sol";
import "../utils/ZgsSpec.sol";
import "../utils/MarketSpec.sol";

contract ChunkLinearReward is ChunkRewardBase {
    using RewardLibrary for Reward;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    uint public immutable releaseSeconds;

    constructor(uint releaseSeconds_) {
        releaseSeconds = releaseSeconds_;
    }

    function _releasedReward(Reward memory reward) internal view override returns (uint) {
        return reward.linearDecayReward(releaseSeconds);
    }

    function _baseReward(uint, Reward memory reward, uint) internal view override returns (uint) {
        if (reward.startTime + releaseSeconds > block.timestamp) {
            return baseReward;
        } else {
            return 0;
        }
    }

    function rewardDeadline(uint pricingIndex) public view returns (uint) {
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
