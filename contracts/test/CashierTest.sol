// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../cashier/Cashier.sol";
import "../reward/Reward.sol";
import "../token/MockHackToken.sol";

contract CashierTest is Cashier {
    MockHackToken public immutable zgsToken;

    constructor(
        address book,
        address uploadToken,
        address stake,
        address zgsToken_
    ) payable Cashier(book, uploadToken, stake) {
        zgsToken = MockHackToken(zgsToken_);
    }

    function updateTotalSubmission(uint256 sectors) external {
        _updateTotalSubmission(sectors);
    }

    function setGauge(int256 gauge_) external {
        _tick();
        gauge = gauge_;
    }

    function _receiveFee(uint256 actualFee, uint256 priorFee)
        internal
        override
    {
        if (actualFee > priorFee) {
            zgsToken.transferFrom(
                msg.sender,
                address(this),
                actualFee - priorFee
            );
        }
        if (priorFee > 0) {
            zgsToken.transferFrom(msg.sender, stake, priorFee);
        }
    }
}
