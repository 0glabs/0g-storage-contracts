import { ZeroAddress } from "ethers";
import { NetworkConfigs } from "../config";

export const ZerogContractConfigs: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initDifficulty: 180000,
        targetMineBlocks: 600,
        targetSubmissions: 5,
        maxShards: 32,
        nSubtasks: 1,
        subtaskInterval: 600, // Sequential, no overlap
    },
    chunkRewardConfigs: {
        foundationAdmin: "0x711b0EcB072C27DE0e50c9944d7195A51B202522", // Foundation admin address
    },
    blocksPerEpoch: 1200,
    firstBlock: 0,
    rootHistory: ZeroAddress,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
    unitPrice: 1,
};
