import { ZeroAddress } from "ethers";
import { NetworkConfigs } from "../config";

export const ZerogTestnetContractConfigsTurbo: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initDifficulty: 180000,
    },
    blocksPerEpoch: 200,
    firstBlock: 595043,
    rootHistory: ZeroAddress,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
    unitPrice: 10,
};
