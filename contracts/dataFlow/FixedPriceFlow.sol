// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./Flow.sol";
import "../market/FixedPrice.sol";

contract FixedPriceFlow is Flow {
    FixedPrice public immutable market;

    constructor(
        address book_,
        uint256 blocksPerEpoch_,
        uint256 deployDelay_
    ) Flow(book_, deployDelay_, blocksPerEpoch_) {
        market = FixedPrice(payable(address(book.market())));
    }

    function _beforeSubmit(uint256 sectors) internal override {
        payable(address(market)).transfer(sectors * market.pricePerSector());
    }
}
