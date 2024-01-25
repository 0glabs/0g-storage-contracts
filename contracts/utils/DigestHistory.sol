// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDigestHistory.sol";

contract DigestHistory is IDigestHistory, Ownable {
    bytes32[] private digests;
    uint256 private nextIndex;

    error UnavailableIndex(uint256);

    constructor(uint256 capacity) {
        digests = new bytes32[](capacity);
        nextIndex = 0;
    }

    function insert(bytes32 data) external returns (uint256) {
        uint256 index = nextIndex;
        uint256 slot = nextIndex % digests.length;
        digests[slot] = data;
        nextIndex += 1;
        return index;
    }

    function available(uint256 index) public view returns (bool) {
        uint256 capacity = digests.length;
        return
            index < nextIndex &&
            index >= Math.max(nextIndex, capacity) - capacity;
    }

    function contains(bytes32 input) external view returns (bool) {
        uint256 maxIndex = Math.min(nextIndex, digests.length);
        for (uint256 i = 0; i < maxIndex; i++) {
            if (digests[i] == input) {
                return true;
            }
        }
        return false;
    }

    function at(uint256 index) external view returns (bytes32) {
        if (!available(index)) {
            revert UnavailableIndex(index);
        }
        return digests[index % digests.length];
    }
}
