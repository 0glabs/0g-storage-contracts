// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../cashier/Cashier.sol";
import "../reward/Reward.sol";
import "../token/MockHackToken.sol";

contract CashierTest is Cashier {
    MockHackToken public immutable zgsToken;
    uint public flowLength;

    constructor(address zgsToken_) payable {
        zgsToken = MockHackToken(zgsToken_);
    }
    
    function initialize(
        address flow_,
        address mine_,
        address reward_,
        address uploadToken_,
        address stake_
    ) public payable override onlyInitializeOnce {
        Cashier._initialize(flow_, mine_, reward_, uploadToken_, stake_);
        flowLength = 1;
    }

    function updateTotalSubmission(uint sectors) external {
        flowLength += sectors;
        _updateDrippingRate(flowLength);
    }

    function chargeFeeTest(uint uploadSectors, uint paddingSectors) external {
        chargeFee(flowLength, uploadSectors, paddingSectors);
        flowLength += uploadSectors + paddingSectors;
    }

    function setGauge(int gauge_) external {
        _tick();
        gauge = gauge_;
    }

    function _receiveFee(uint actualFee, uint priorFee) internal override {
        if (actualFee > priorFee) {
            zgsToken.transferFrom(msg.sender, address(this), actualFee - priorFee);
        }
        if (priorFee > 0) {
            zgsToken.transferFrom(msg.sender, stake, priorFee);
        }
    }
}
