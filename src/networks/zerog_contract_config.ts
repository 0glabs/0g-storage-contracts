import { NetworkConfigs } from "../config";

export const ZerogContractConfigs: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initHashRate: 1000,
        adjustRatio: 20,
    },
    blocksPerEpoch: 1000000000,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
};
