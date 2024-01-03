// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/utils/Context.sol";

contract OnlySender is Context{
    modifier onlySender(address sender) {
        require(_msgSender()==sender, "Sender does not have permission");
        _;
    }
}