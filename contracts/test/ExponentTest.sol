// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/Exponent.sol";

contract ExponentTest {
    function powTwo(uint exponentX64) public pure returns (uint) {
        return Exponential.powTwo64X96(exponentX64);
    }

    function powHalf(uint exponentX64) public pure returns (uint) {
        return Exponential.powHalf64X96(exponentX64);
    }
}
