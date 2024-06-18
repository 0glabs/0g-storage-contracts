// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./Flow.sol";
import "../market/FixedPrice.sol";

contract FixedPriceFlow is Flow {
    FixedPrice public immutable market;

    error NotEnoughFee(uint price, uint amount, uint paid);

    constructor(address book_, uint blocksPerEpoch_, uint deployDelay_) Flow(book_, blocksPerEpoch_, deployDelay_) {
        market = FixedPrice(payable(address(book.market())));
    }

    function _beforeSubmit(uint sectors) internal override {
        uint price = market.pricePerSector();
        uint fee = sectors * price;
        uint paid = address(this).balance;

        if (fee > address(this).balance) {
            revert NotEnoughFee(price, sectors, paid);
        }

        payable(address(market)).transfer(fee);
    }
}
