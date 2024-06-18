// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDigestHistory.sol";

contract DigestHistory is IDigestHistory, Ownable {
    bytes32[] private digests;
    uint private nextIndex;

    error UnavailableIndex(uint);

    constructor(uint capacity) {
        digests = new bytes32[](capacity);
        nextIndex = 0;
    }

    function insert(bytes32 data) external returns (uint) {
        uint index = nextIndex;
        uint slot = nextIndex % digests.length;
        digests[slot] = data;
        nextIndex += 1;
        return index;
    }

    function available(uint index) public view returns (bool) {
        uint capacity = digests.length;
        return index < nextIndex && index >= Math.max(nextIndex, capacity) - capacity;
    }

    function contains(bytes32 input) external view returns (bool) {
        uint maxIndex = Math.min(nextIndex, digests.length);
        for (uint i = 0; i < maxIndex; i++) {
            if (digests[i] == input) {
                return true;
            }
        }
        return false;
    }

    function at(uint index) external view returns (bytes32) {
        if (!available(index)) {
            revert UnavailableIndex(index);
        }
        return digests[index % digests.length];
    }
}
