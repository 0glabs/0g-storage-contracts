// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

interface IDigestHistory {
    function insert(bytes32 data) external returns (uint256);

    function available(uint256 index) external view returns (bool);

    function contains(bytes32 input) external view returns (bool);

    function at(uint256 index) external view returns (bytes32);
}
