// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./IUploadToken.sol";

import "../../utils/Exponent.sol";
import "../../utils/OnlySender.sol";
import "../../token/ISafeERC20.sol";

contract UploadToken is ERC20, IUploadToken, OnlySender {
    uint public immutable blockInterval;
    address public immutable battery;
    address public immutable peakSwap;
    address public immutable cashier;

    mapping(address => uint) public lastUpdate;

    uint private constant MILLISECONDS_PER_WEEK = 604800000;

    constructor(
        address battery_,
        address peakSwap_,
        address cashier_,
        uint blockInterval_
    ) ERC20("ZeroGStorage Upload Token", "ZGS-UPL") {
        blockInterval = blockInterval_;

        battery = battery_;
        peakSwap = peakSwap_;
        cashier = cashier_;
    }

    function _isSpecialAddress(address account) internal view returns (bool) {
        return account == address(0) || account == battery || account == peakSwap;
    }

    function realBalanceOf(address account) public view returns (uint realBalance) {
        uint lastBalance = ERC20.balanceOf(account);
        if (lastBalance == 0) {
            return 0;
        }
        if (_isSpecialAddress(account)) {
            return lastBalance;
        }

        uint lastBlockNumber = lastUpdate[account];
        uint currentBlockNumber = block.number;

        uint timeDelta = blockInterval * (currentBlockNumber - lastBlockNumber);
        uint decayExponentX64 = (timeDelta * (1 << 64)) / MILLISECONDS_PER_WEEK;

        realBalance = (Exponential.powHalf64X96(decayExponentX64) * lastBalance) >> 96;
    }

    function updateBalance(address account) public {
        if (_isSpecialAddress(account)) {
            return;
        }
        uint storedBalance = ERC20.balanceOf(account);
        uint realBalance = realBalanceOf(account);
        if (storedBalance == realBalance) {
            return;
        }
        _burn(account, storedBalance - realBalance);
    }

    function _beforeTokenTransfer(address from, address to, uint) internal override {
        if (to == address(0)) {
            return;
        }
        updateBalance(from);
        updateBalance(to);
    }

    function balanceOf(address account) public view override(ERC20, IERC20) returns (uint) {
        return realBalanceOf(account);
    }

    function mintForMarket(uint amount) external onlySender(peakSwap) {
        _mint(peakSwap, amount);
    }

    function consume(address consumer, uint amount) external onlySender(cashier) {
        _spendAllowance(consumer, cashier, amount);
        _burn(consumer, amount);
    }
}
