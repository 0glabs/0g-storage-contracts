// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/AddressBook.sol";
import "../utils/MarketSpec.sol";

import "@openzeppelin/contracts/utils/Context.sol";

contract FixedPrice is IMarket, Context {
    AddressBook public immutable book;
    uint256 public immutable pricePerSector;

    constructor(address book_, uint256 lifetimeMonthes) {
        book = AddressBook(book_);
        pricePerSector = lifetimeMonthes * MONTH_ZGS_UNITS_PER_SECTOR;
    }

    function chargeFee(
        uint256 beforeLength,
        uint256 uploadSectors,
        uint256 paddingSectors
    ) external {
        require(
            _msgSender() == address(book.flow()),
            "Sender does not have permission"
        );

        uint256 totalSectors = uploadSectors + paddingSectors;
        uint256 baseFee = pricePerSector * uploadSectors;
        require(baseFee <= address(this).balance, "Not enough paid fee");
        uint256 bonus = address(this).balance - baseFee;

        uint256 paddingPart = (baseFee * paddingSectors) / totalSectors;
        uint256 uploadPart = baseFee - paddingPart;

        if (paddingSectors > 0) {
            book.reward().fillReward{value: paddingPart}(
                beforeLength,
                paddingSectors
            );
        }

        book.reward().fillReward{value: bonus + uploadPart}(
            beforeLength + paddingSectors,
            uploadSectors
        );
    }

    receive() external payable {}
}
