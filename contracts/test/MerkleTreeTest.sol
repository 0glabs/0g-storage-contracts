// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "../dataFlow/IncrementalMerkleTree.sol";

contract MerkleTreeTest is IncrementalMerkleTree {
    function insertNode(bytes32 nodeRoot, uint height) external returns (uint) {
        return _insertNode(nodeRoot, height);
    }
}
