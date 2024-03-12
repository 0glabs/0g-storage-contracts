// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./IUploadToken.sol";

import "../../utils/Exponent.sol";
import "../../utils/OnlySender.sol";
import "../../token/ISafeERC20.sol";

contract UploadToken is ERC20, IUploadToken, OnlySender {
    uint256 public immutable blockInterval;
    address public immutable battery;
    address public immutable peakSwap;
    address public immutable cashier;

    mapping(address => uint256) public lastUpdate;

    uint256 private constant MILLISECONDS_PER_WEEK = 604800000;

    constructor(
        address battery_,
        address peakSwap_,
        address cashier_,
        uint256 blockInterval_
    ) ERC20("ZeroGStorage Upload Token", "ZGS-UPL") {
        blockInterval = blockInterval_;

        battery = battery_;
        peakSwap = peakSwap_;
        cashier = cashier_;
    }

    function _isSpecialAddress(address account) internal view returns (bool) {
        return
            account == address(0) || account == battery || account == peakSwap;
    }

    function realBalanceOf(address account)
        public
        view
        returns (uint256 realBalance)
    {
        uint256 lastBalance = ERC20.balanceOf(account);
        if (lastBalance == 0) {
            return 0;
        }
        if (_isSpecialAddress(account)) {
            return lastBalance;
        }

        uint256 lastBlockNumber = lastUpdate[account];
        uint256 currentBlockNumber = block.number;

        uint256 timeDelta = blockInterval *
            (currentBlockNumber - lastBlockNumber);
        uint256 decayExponentX64 = (timeDelta * (1 << 64)) /
            MILLISECONDS_PER_WEEK;

        realBalance =
            (Exponential.powHalf64X96(decayExponentX64) * lastBalance) >>
            96;
    }

    function updateBalance(address account) public {
        if (_isSpecialAddress(account)) {
            return;
        }
        uint256 storedBalance = ERC20.balanceOf(account);
        uint256 realBalance = realBalanceOf(account);
        if (storedBalance == realBalance) {
            return;
        }
        _burn(account, storedBalance - realBalance);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        if (to == address(0)) {
            return;
        }
        updateBalance(from);
        updateBalance(to);
    }

    function balanceOf(address account)
        public
        view
        override(ERC20, IERC20)
        returns (uint256)
    {
        return realBalanceOf(account);
    }

    function mintForMarket(uint256 amount) external onlySender(peakSwap) {
        _mint(peakSwap, amount);
    }

    function consume(address consumer, uint256 amount)
        external
        onlySender(cashier)
    {
        _spendAllowance(consumer, cashier, amount);
        _burn(consumer, amount);
    }
}
