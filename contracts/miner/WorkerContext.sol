// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../interfaces/IFlow.sol";

struct WorkerContext {
    MineContext context;
    uint poraTarget;
    bytes32 subtaskDigest;
    uint64 maxShards;
}