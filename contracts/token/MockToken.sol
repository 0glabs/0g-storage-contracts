// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ISafeERC20.sol";

contract MockToken is ERC20, ISafeERC20 {

    constructor() ERC20("Mock ZeroGStorage Token", "ZGS") {
        _mint(msg.sender, 1e9);
    }
}
