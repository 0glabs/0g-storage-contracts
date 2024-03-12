// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "./Reward.sol";
import "./ChunkRewardBase.sol";
import "../utils/MarketSpec.sol";

contract ChunkDecayReward is ChunkRewardBase {
    using RewardLibrary for Reward;
    uint16 public immutable annualMilliDecayRate;

    constructor(address book_, uint16 annualMilliDecayRate_)
        ChunkRewardBase(book_)
    {
        annualMilliDecayRate = annualMilliDecayRate_;
    }

    function _releasedReward(Reward memory reward)
        internal
        view
        override
        returns (uint256)
    {
        return reward.expDecayReward(annualMilliDecayRate);
    }
}
