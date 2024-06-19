// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./Flow.sol";
import "../market/FixedPrice.sol";

contract FixedPriceFlow is Flow {
    error NotEnoughFee(uint price, uint amount, uint paid);

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    constructor(uint blocksPerEpoch_, uint deployDelay_) Flow(blocksPerEpoch_, deployDelay_) {}

    function _initialize(address market_) internal override {
        Flow._initialize(market_);
    }

    function initialize(address market_) public override onlyInitializeOnce {
        _initialize(market_);
    }

    function _beforeSubmit(uint sectors) internal override {
        uint price = FixedPrice(market).pricePerSector();
        uint fee = sectors * price;
        uint paid = address(this).balance;

        if (fee > address(this).balance) {
            revert NotEnoughFee(price, sectors, paid);
        }

        payable(address(market)).transfer(fee);
    }
}
