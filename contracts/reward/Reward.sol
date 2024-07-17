// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/Exponent.sol";
import "../utils/ZgsSpec.sol";

struct Reward {
    uint128 lockedReward;
    uint128 claimableReward;
    uint128 distributedReward;
    uint40 startTime;
    uint40 lastUpdate;
}

library RewardLibrary {
    function addReward(Reward storage reward, uint amount, bool finalized) internal {
        require(amount <= type(uint128).max, "Reward overflow");
        require(reward.startTime == 0, "Reward item has been initialized");

        reward.lockedReward += uint128(amount);
        if (finalized) {
            reward.startTime = uint40(block.timestamp);
            reward.lastUpdate = uint40(block.timestamp);
        }
    }

    function updateReward(Reward memory reward, uint releaseReward) internal view {
        reward.lockedReward -= uint128(releaseReward);
        reward.claimableReward += uint128(releaseReward);
        reward.lastUpdate = uint40(block.timestamp);
    }

    function expDecayReward(Reward memory reward, uint annualMilliDecayRate) internal view returns (uint) {
        if (reward.startTime == 0) {
            return 0;
        }

        uint timeElapsed = (block.timestamp - reward.lastUpdate) * 1000;
        uint decayX64 = (timeElapsed * uint(Exponential.INV_LOG2X128) * annualMilliDecayRate) /
            (1 << 64) /
            MILLI_SECONDS_PER_YEAR /
            1000;
        uint releaseX96 = (1 << 96) - Exponential.powHalf64X96(decayX64);
        return (releaseX96 * uint(reward.lockedReward)) / (1 << 96);
    }

    function linearDecayReward(Reward memory reward, uint releaseSeconds) internal view returns (uint) {
        if (reward.lastUpdate == 0) {
            return 0;
        }

        uint releasedReward = reward.claimableReward + reward.distributedReward;
        uint totalReward = reward.lockedReward + releasedReward;

        uint timeElapsedSinceLaunch = block.timestamp - reward.startTime;

        uint expectedReleasedReward = (totalReward * timeElapsedSinceLaunch) / releaseSeconds;
        if (expectedReleasedReward > totalReward) {
            expectedReleasedReward = totalReward;
        }
        if (expectedReleasedReward < releasedReward) {
            return 0;
        }
        return expectedReleasedReward - releasedReward;
    }

    function claimReward(Reward memory reward) internal pure returns (uint amount) {
        uint128 claimedReward = reward.claimableReward / 2;
        reward.claimableReward -= claimedReward;
        reward.distributedReward += claimedReward;

        return uint(claimedReward);
    }
}
