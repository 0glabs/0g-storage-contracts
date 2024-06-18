// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";

contract DummyMarket is IMarket {
    function chargeFee(uint beforeLength, uint uploadSectors, uint paddingSectors) external {}
}

contract DummyReward is IReward {
    function fillReward(uint beforeLength, uint uploadSectors) external payable {}

    function claimMineReward(uint pricingIndex, address payable beneficiary, bytes32 minerId) external {}
}

contract AddressBook {
    IMarket public immutable market;
    IReward public immutable reward;
    IFlow public immutable flow;
    address public immutable mine;

    constructor(address flow_, address market_, address reward_, address mine_) {
        flow = IFlow(flow_);
        if (market_ == address(0)) {
            market_ = address(new DummyMarket());
        }
        market = IMarket(market_);

        if (reward_ == address(0)) {
            reward_ = address(new DummyReward());
        }
        reward = IReward(reward_);

        mine = mine_;
    }
}
