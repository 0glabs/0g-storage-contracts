// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../utils/MarketSpec.sol";
import "../utils/Initializable.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FixedPrice is IMarket, Context, Ownable, Initializable {
    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    uint public pricePerSector;

    address public flow;
    address public reward;

    function initialize(uint lifetimeMonthes, address flow_, address reward_) public onlyInitializeOnce {
        pricePerSector = lifetimeMonthes * MONTH_ZGS_UNITS_PER_SECTOR;
        flow = flow_;
        reward = reward_;
    }

    function setPricePerSector(uint pricePerSector_) external onlyOwner {
        pricePerSector = pricePerSector_;
    }

    function chargeFee(uint beforeLength, uint uploadSectors, uint paddingSectors) external {
        require(_msgSender() == flow, "Sender does not have permission");

        uint totalSectors = uploadSectors + paddingSectors;
        uint baseFee = pricePerSector * uploadSectors;
        require(baseFee <= address(this).balance, "Not enough paid fee");
        uint bonus = address(this).balance - baseFee;

        uint paddingPart = (baseFee * paddingSectors) / totalSectors;
        uint uploadPart = baseFee - paddingPart;

        if (paddingSectors > 0) {
            IReward(reward).fillReward{value: paddingPart}(beforeLength, paddingSectors);
        }

        IReward(reward).fillReward{value: bonus + uploadPart}(beforeLength + paddingSectors, uploadSectors);
    }

    receive() external payable {}
}
