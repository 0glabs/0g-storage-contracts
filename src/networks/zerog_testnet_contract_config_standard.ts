import { ZeroAddress } from "ethers";
import { NetworkConfigs } from "../config";

export const ZerogTestnetContractConfigsStandard: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initDifficulty: 180000,
        targetMineBlocks: 100,
        targetSubmissions: 10,
        maxShards: 32,
        nSubtasks: 1,
        subtaskInterval: 100, // Sequential, no overlap
    },
    blocksPerEpoch: 200,
    firstBlock: 594994,
    rootHistory: ZeroAddress,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
    unitPrice: 1,
};
