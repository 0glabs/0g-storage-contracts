import { ZerogContractConfigs } from "./networks/zerog_contract_config";

export interface MineConfigs {
    settings: number;
    // The initial hash rate for PoRA mining.
    initHashRate: number;
    adjustRatio: number;
}

export interface NetworkConfigs {
    mineConfigs: MineConfigs;
    // This variable determines how often the `makeContext` function needs to be called within each mining cycle, known as an Epoch. If this function is not called over several epochs, it may cause issues. By default, this value is set very high, meaning that the contract will not generate mining tasks. For mining tests, adjust it to a suitable size (recommended block count per hour).
    blocksPerEpoch: number;
    // Upon enabling the economic model, this controls the data storage validity period and the reward release cycle. The annual storage cost per GB is a constant in the contract named `ANNUAL_ZGS_TOKENS_PER_GB`.
    lifetimeMonth: number;
    flowDeployDelay: number;
}

export const DefaultConfig: NetworkConfigs = {
    mineConfigs: {
        settings: 0,
        initHashRate: 1000,
        adjustRatio: 20,
    },
    blocksPerEpoch: 1000000000,
    lifetimeMonth: 3,
    flowDeployDelay: 0,
};

export const GlobalConfig: { [key: string]: NetworkConfigs } = {
    zg: ZerogContractConfigs,
};

export function getConfig(network: string) {
    if (network in GlobalConfig) return GlobalConfig[network];
    if (network === "hardhat") {
        return DefaultConfig;
    }
    throw new Error(`network ${network} non-exist`);
}
