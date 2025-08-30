import { ZeroAddress } from "ethers";
import { NetworkConfigs } from "../config";

export const ZerogTestnetContractConfigsTurbo: NetworkConfigs = {
    mineConfigs: {
        settings: 0, // | `settings` | `uint` | Bit flags for mining features | Bitwise flags: NO_DATA_SEAL (0x1), NO_DATA_PROOF (0x2), FIXED_DIFFICULTY (0x4) | No         |
        initDifficulty: 1000000,
        targetMineBlocks: 750, // 5min = 300s, with 0.4s per block
        targetSubmissions: 5000, // n x 8GB > throughput GB/s * epoch window = 25 min, n/nSubtasks * nOverlapSubtasks * poraGas < tps (166) * 21000 * targetMineBlock
        maxShards: 8,
        nSubtasks: 4,
        subtaskInterval: 800, // non-overlap, (0, 750], (800, 1550],...
    },
    blocksPerEpoch: 3750,
    firstBlock: 1,
    rootHistory: ZeroAddress,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
    unitPrice: 0.04296875,
};
