// SPDX-License-Identifier: Unlicense

pragma solidity >=0.8.0 <0.9.0;

import "./Reward.sol";
import "./ChunkRewardBase.sol";
import "../utils/ZgsSpec.sol";
import "../utils/MarketSpec.sol";

contract ChunkLinearReward is ChunkRewardBase {
    using RewardLibrary for Reward;

    uint16 public immutable releaseMonths;

    constructor(address book_, uint16 releaseMonths_) ChunkRewardBase(book_) {
        releaseMonths = releaseMonths_;
    }

    function _releasedReward(Reward memory reward) internal view override returns (uint) {
        return reward.linearDecayReward(releaseMonths);
    }
}
