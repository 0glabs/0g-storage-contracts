// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../token/ISafeERC20.sol";

contract BatteryToken is ERC20, ISafeERC20 {
    ISafeERC20 public uploadToken;
    mapping(address => uint) public chargedBalance;

    constructor(address _uploadToken, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        uploadToken = ISafeERC20(_uploadToken);
    }

    function _beforeTokenTransfer(address from, address, uint amount) internal view override {
        require(chargedBalance[from] + amount >= balanceOf(from), "Balance < Charged balance");
    }

    function charge(uint amount) external {
        _charge(msg.sender, msg.sender, amount);
    }

    function chargeFor(address beneficiary, uint amount) external {
        _charge(msg.sender, beneficiary, amount);
    }

    function uncharge(uint amount) external {
        _uncharge(msg.sender, msg.sender, amount);
    }

    function unchargeFor(address beneficiary, uint amount) external {
        _uncharge(msg.sender, beneficiary, amount);
    }

    function _charge(address from, address to, uint amount) internal {
        uploadToken.transferFrom(from, address(this), amount);
        chargedBalance[to] += amount;
        require(chargedBalance[to] >= balanceOf(to), "Balance < Charged balance");
    }

    function _uncharge(address from, address to, uint amount) internal {
        require(chargedBalance[from] >= amount, "Not enought charged balance");
        unchecked {
            chargedBalance[from] -= amount;
        }

        uploadToken.transfer(to, amount);
    }
}
