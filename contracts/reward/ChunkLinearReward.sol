// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "./Reward.sol";
import "./ChunkRewardBase.sol";
import "../utils/ZgsSpec.sol";
import "../utils/MarketSpec.sol";
import "../utils/Initializable.sol";

contract ChunkLinearReward is Initializable, ChunkRewardBase {
    using RewardLibrary for Reward;

    uint16 public immutable releaseMonths;

    constructor(uint16 releaseMonths_) {
        releaseMonths = releaseMonths_;
    }

    function _releasedReward(Reward memory reward) internal view override returns (uint) {
        return reward.linearDecayReward(releaseMonths);
    }
}
