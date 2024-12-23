// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8;

library DeepCopy {
    function deepCopy(bytes32[2] memory src) internal pure returns (bytes32[2] memory dst) {
        dst[0] = src[0];
        dst[1] = src[1];
    }
}
