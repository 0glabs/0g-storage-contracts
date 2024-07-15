// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract ZgInitializable {
    bool public initialized;

    modifier onlyInitializeOnce() {
        require(!initialized, "ZgInitializable: already initialized");
        initialized = true;
        _;
    }
}
