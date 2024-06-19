// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "./Reward.sol";
import "./ChunkRewardBase.sol";
import "../utils/MarketSpec.sol";
import "../utils/Initializable.sol";

contract ChunkDecayReward is Initializable, ChunkRewardBase {
    using RewardLibrary for Reward;
    uint16 public immutable annualMilliDecayRate;

    constructor(uint16 annualMilliDecayRate_) {
        annualMilliDecayRate = annualMilliDecayRate_;
    }

    function _releasedReward(Reward memory reward) internal view override returns (uint) {
        return reward.expDecayReward(annualMilliDecayRate);
    }
}
