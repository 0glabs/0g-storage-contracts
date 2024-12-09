import { ZeroAddress } from "ethers";
import { NetworkConfigs } from "../config";

export const ZerogContractConfigs: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initDifficulty: 180000,
    },
    blocksPerEpoch: 1200,
    firstBlock: 0,
    rootHistory: ZeroAddress,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
    unitPrice: 1,
};
