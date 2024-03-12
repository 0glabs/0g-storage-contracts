// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/Exponent.sol";

uint256 constant DAYS_PER_MONTH = 31;
uint256 constant SECONDS_PER_MONTH = 86400 * DAYS_PER_MONTH;

uint256 constant DAYS_PER_YEAR = 365;
uint256 constant SECONDS_PER_YEAR = 86400 * DAYS_PER_YEAR;
uint256 constant MILLI_SECONDS_PER_YEAR = 1000 * SECONDS_PER_YEAR;

struct Reward {
    uint128 lockedReward;
    uint128 claimableReward;
    uint128 distributedReward;
    uint40 startTime;
    uint40 lastUpdate;
}

library RewardLibrary {
    function addReward(
        Reward storage reward,
        uint256 amount,
        bool finalized
    ) internal {
        require(amount <= type(uint128).max, "Reward overflow");
        require(reward.startTime == 0, "Reward item has been initialized");

        reward.lockedReward += uint128(amount);
        if (finalized) {
            reward.startTime = uint40(block.timestamp);
            reward.lastUpdate = uint40(block.timestamp);
        }
    }

    function updateReward(Reward memory reward, uint256 releaseReward)
        internal
        view
    {
        reward.lockedReward -= uint128(releaseReward);
        reward.claimableReward += uint128(releaseReward);
        reward.lastUpdate = uint40(block.timestamp);
    }

    function expDecayReward(Reward memory reward, uint256 annualMilliDecayRate)
        internal
        view
        returns (uint256)
    {
        if (reward.startTime == 0) {
            return 0;
        }

        uint256 timeElapsed = (block.timestamp - reward.lastUpdate) * 1000;
        uint256 decayX64 = (timeElapsed *
            uint256(Exponential.INV_LOG2X128) *
            annualMilliDecayRate) /
            (1 << 64) /
            MILLI_SECONDS_PER_YEAR /
            1000;
        uint256 releaseX96 = (1 << 96) - Exponential.powHalf64X96(decayX64);
        return (releaseX96 * uint256(reward.lockedReward)) / (1 << 96);
    }

    function linearDecayReward(Reward memory reward, uint256 releaseMonth)
        internal
        view
        returns (uint256)
    {
        if (reward.lastUpdate == 0) {
            return 0;
        }

        uint256 releasedReward = reward.claimableReward +
            reward.distributedReward;
        uint256 totalReward = reward.lockedReward + releasedReward;

        uint256 timeElapsedSinceLaunch = block.timestamp - reward.startTime;

        uint256 expectedReleasedReward = (totalReward *
            timeElapsedSinceLaunch) /
            releaseMonth /
            SECONDS_PER_MONTH;
        if (expectedReleasedReward > totalReward) {
            expectedReleasedReward = totalReward;
        }
        if (expectedReleasedReward < releasedReward) {
            return 0;
        }
        return expectedReleasedReward - releasedReward;
    }

    function claimReward(Reward memory reward)
        internal
        pure
        returns (uint256 amount)
    {
        uint128 claimedReward = reward.claimableReward / 2;
        reward.claimableReward -= claimedReward;
        reward.distributedReward += claimedReward;

        return uint256(claimedReward);
    }
}
