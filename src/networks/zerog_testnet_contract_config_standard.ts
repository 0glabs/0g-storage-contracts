import { ZeroAddress } from "ethers";
import { NetworkConfigs } from "../config";

export const ZerogTestnetContractConfigsStandard: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initDifficulty: 1000000,
    },
    blocksPerEpoch: 1200,
    firstBlock: 326165,
    rootHistory: ZeroAddress,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
    unitPrice: 1,
};
