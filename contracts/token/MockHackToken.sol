// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ISafeERC20.sol";

// In previous, zgsToken is an ERC20 token. However, it becomes a native token now.
// This is a hotfix contract for making existing test code be compatible.
// It is not intended for more usage.
contract MockHackToken is ERC20, ISafeERC20 {
    constructor() ERC20("Mock ZeroGStorage Token", "ZGS") {
        _mint(msg.sender, 1000);
    }

    function _update(address from, address to, uint amount) internal override {
        super._update(from, to, amount);
        if (to == address(0)) {
            return;
        }
        _burn(to, amount);
        payable(to).transfer(amount);
    }

    function receiveNative() external payable {}
}
