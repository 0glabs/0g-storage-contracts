// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./ISafeERC20.sol";

interface IUploadToken is ISafeERC20 {
    function mintForMarket(uint256 amount) external;

    function consume(address consumer, uint256 amount) external;
}
