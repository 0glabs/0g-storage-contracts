// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ISafeERC20.sol";

contract StakeToken is ERC20, ISafeERC20 {
    constructor() ERC20("Staked ZeroGStorage", "sZGS") {}

    event Stake(address indexed sender, uint zgsAmount, uint stakeAmount);
    event Unstake(address indexed sender, uint zgsAmount, uint stakeAmount);

    ISafeERC20 public zgsToken;

    function stake(uint depositAmount) public {
        uint zgsBalance = zgsToken.balanceOf(address(this));
        zgsToken.transferFrom(msg.sender, address(this), depositAmount);

        uint supply = totalSupply();
        uint mintAmount = (depositAmount * supply) / zgsBalance;

        _mint(msg.sender, mintAmount);
        emit Stake(msg.sender, depositAmount, mintAmount);
    }

    function unstake(uint burnAmount) public {
        uint zgsBalance = zgsToken.balanceOf(address(this));

        uint supply = totalSupply();
        uint claimAmount = (burnAmount * zgsBalance) / supply;

        zgsToken.transfer(msg.sender, burnAmount);
        _burn(msg.sender, burnAmount);
        emit Unstake(msg.sender, claimAmount, burnAmount);
    }
}
