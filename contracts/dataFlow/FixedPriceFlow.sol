// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./Flow.sol";
import "../market/FixedPrice.sol";

contract FixedPriceFlow is Flow {
    FixedPrice public immutable market;

    error NotEnoughFee(uint256 price, uint256 amount, uint256 paid);

    constructor(
        address book_,
        uint256 blocksPerEpoch_,
        uint256 deployDelay_
    ) Flow(book_, blocksPerEpoch_, deployDelay_) {
        market = FixedPrice(payable(address(book.market())));
    }

    function _beforeSubmit(uint256 sectors) internal override {
        uint256 price = market.pricePerSector();
        uint256 fee = sectors * price;
        uint256 paid = address(this).balance;

        if (fee > address(this).balance) {
            revert NotEnoughFee(price, sectors, paid);
        }

        payable(address(market)).transfer(fee);
    }
}
