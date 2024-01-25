// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/Exponent.sol";

contract ExponentTest {
    function powTwo(uint256 exponentX64) public pure returns (uint256) {
        return Exponential.powTwo64X96(exponentX64);
    }

    function powHalf(uint256 exponentX64) public pure returns (uint256) {
        return Exponential.powHalf64X96(exponentX64);
    }
}
