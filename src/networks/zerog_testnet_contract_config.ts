import { NetworkConfigs } from "../config";

export const ZerogTestnetContractConfigs: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initHashRate: 6000,
        adjustRatio: 20,
    },
    blocksPerEpoch: 1200,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
};
