// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/Exponent.sol";

uint256 constant DAYS_PER_YEAR = 365;
uint256 constant SECONDS_PER_YEAR = 86400 * DAYS_PER_YEAR;
uint256 constant MILLI_SECONDS_PER_YEAR = 1000 * SECONDS_PER_YEAR;

struct Reward {
    uint104 lockedReward;
    uint104 claimableReward;
    uint48 timestamp;
}

library RewardLibrary {
    function addReward(
        Reward storage reward,
        uint256 amount,
        bool finalized
    ) internal {
        require(amount <= type(uint104).max, "Reward overflow");
        require(reward.timestamp == 0, "Reward has been finalized");

        reward.lockedReward += uint104(amount);
        if (finalized) {
            reward.timestamp = uint48(block.timestamp);
        }
    }

    function claimReward(Reward storage reward)
        internal
        returns (uint256 amount)
    {
        if (reward.timestamp == 0) {
            return 0;
        }

        uint256 timeElapsed = (block.timestamp - reward.timestamp) * 1000;
        uint256 decayX64 = (timeElapsed *
            uint256(Exponential.INV_LOG2X128) *
            4) /
            (1 << 64) /
            MILLI_SECONDS_PER_YEAR /
            100;
        uint256 releaseX96 = (1 << 96) - Exponential.powHalf64X96(decayX64);
        uint104 releaseReward = uint104(
            (releaseX96 * uint256(reward.lockedReward)) / (1 << 96)
        );

        reward.lockedReward -= releaseReward;
        reward.claimableReward += releaseReward;
        reward.timestamp = uint48(block.timestamp);

        uint104 claimedReward = reward.claimableReward / 2;
        reward.claimableReward -= claimedReward;

        return uint256(claimedReward);
    }
}
