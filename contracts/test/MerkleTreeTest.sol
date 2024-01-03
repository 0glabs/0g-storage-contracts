// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "../dataFlow/IncrementalMerkleTree.sol";

contract MerkleTreeTest is IncrementalMerkleTree {
    constructor() IncrementalMerkleTree(bytes32(0x0)) {}

    function insertNode(bytes32 nodeRoot, uint256 height)
        external
        returns (uint256)
    {
        return _insertNode(nodeRoot, height);
    }
}
