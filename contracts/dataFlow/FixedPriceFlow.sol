// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./Flow.sol";
import "../market/FixedPrice.sol";

contract FixedPriceFlow is Flow {
    error NotEnoughFee(uint price, uint amount, uint paid);

    constructor(uint deployDelay_) Flow(deployDelay_) {}

    function _beforeSubmit(uint sectors, uint value) internal override returns (uint) {
        uint price = FixedPrice(market()).pricePerSector();
        uint fee = sectors * price;

        if (fee > value) {
            revert NotEnoughFee(price, sectors, value);
        }

        payable(address(market())).transfer(fee);
        return value - fee;
    }

    /// @notice Forward the contract's native balance to the market, where it is
    /// distributed to the reward pool with the next fee charge. Balance can only
    /// exist here as residue of overpaid submissions made before fee accounting
    /// was fixed: new submissions charge the exact fee and refund any excess.
    function sweepResidualToMarket() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // transfer's 2300 gas stipend cannot cover the market proxy's cold beacon
        // lookup, so forward all gas instead
        (bool success, ) = market().call{value: address(this).balance}("");
        require(success, "Sweep failed");
    }
}
