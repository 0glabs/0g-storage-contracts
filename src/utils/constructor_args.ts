import { getConfig } from "../config";
import { CONTRACTS } from "./utils";

export function getConstructorArgs(network: string, name: string): unknown[] {
    const config = getConfig(network);
    let args: unknown[] = [];
    switch (name) {
        case CONTRACTS.ChunkLinearReward.name: {
            args = [config.lifetimeMonth * 31 * 86400];
            break;
        }
        case CONTRACTS.FixedPriceFlow.name: {
            args = [config.flowDeployDelay];
            break;
        }
        case CONTRACTS.Flow.name: {
            args = [config.flowDeployDelay];
            break;
        }
        case CONTRACTS.OnePoolReward.name: {
            args = [config.lifetimeMonth * 31 * 86400];
            break;
        }
        case CONTRACTS.PoraMine.name: {
            args = [config.mineConfigs.settings];
            break;
        }
        case CONTRACTS.PoraMineTest.name: {
            args = [config.mineConfigs.settings];
            break;
        }
        default: {
            break;
        }
    }
    return args;
}
