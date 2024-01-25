// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../uploadMarket/Cashier.sol";

contract CashierTest is Cashier {
    constructor(
        address zgsToken,
        address uploadToken,
        address flow,
        address mine,
        address stake
    ) Cashier(zgsToken, uploadToken, flow, mine, stake) {}

    function updateTotalSubmission(uint256 sectors) external {
        _updateTotalSubmission(sectors);
    }

    function setGauge(int256 gauge_) external {
        _tick();
        gauge = gauge_;
    }
}
