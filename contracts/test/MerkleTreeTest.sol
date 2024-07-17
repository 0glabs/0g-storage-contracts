// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "../dataFlow/FlowTreeLib.sol";

contract MerkleTreeTest {
    using FlowTreeLib for FlowTree;
    FlowTree public tree;

    constructor() {
        tree.initialize(bytes32(0x0));
    }

    function insertNode(bytes32 nodeRoot, uint height) external returns (uint) {
        return tree.insertNode(nodeRoot, height);
    }

    function root() external view returns (bytes32) {
        return tree.root();
    }

    function commitRoot() external {
        tree.commitRoot();
    }

    function currentLength() external view returns (uint) {
        return tree.currentLength;
    }

    function unstagedHeight() external view returns (uint) {
        return tree.unstagedHeight;
    }
}
