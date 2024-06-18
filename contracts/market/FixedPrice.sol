// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/AddressBook.sol";
import "../utils/MarketSpec.sol";

import "@openzeppelin/contracts/utils/Context.sol";

contract FixedPrice is IMarket, Context {
    AddressBook public immutable book;
    uint public immutable pricePerSector;

    constructor(address book_, uint lifetimeMonthes) {
        book = AddressBook(book_);
        pricePerSector = lifetimeMonthes * MONTH_ZGS_UNITS_PER_SECTOR;
    }

    function chargeFee(uint beforeLength, uint uploadSectors, uint paddingSectors) external {
        require(_msgSender() == address(book.flow()), "Sender does not have permission");

        uint totalSectors = uploadSectors + paddingSectors;
        uint baseFee = pricePerSector * uploadSectors;
        require(baseFee <= address(this).balance, "Not enough paid fee");
        uint bonus = address(this).balance - baseFee;

        uint paddingPart = (baseFee * paddingSectors) / totalSectors;
        uint uploadPart = baseFee - paddingPart;

        if (paddingSectors > 0) {
            book.reward().fillReward{value: paddingPart}(beforeLength, paddingSectors);
        }

        book.reward().fillReward{value: bonus + uploadPart}(beforeLength + paddingSectors, uploadSectors);
    }

    receive() external payable {}
}
