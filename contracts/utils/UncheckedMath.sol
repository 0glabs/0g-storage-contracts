// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

library UncheckedMath {
    function add(uint a, uint b) internal pure returns (uint) {
        unchecked {
            return a + b;
        }
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        unchecked {
            return a - b;
        }
    }

    function mul(uint a, uint b) internal pure returns (uint) {
        unchecked {
            return a * b;
        }
    }
}
