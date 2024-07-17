import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConfig } from "../config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // initialize all contracts
    const config = getConfig(hre.network.name);
    const poraMine_ = await getTypedContract(hre, CONTRACTS.PoraMine);
    const fixedPriceMarket_ = await getTypedContract(hre, CONTRACTS.FixedPriceMarket);
    const chunkLinearReward_ = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);
    const fixedPriceFlow_ = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);

    const flowAddress = await fixedPriceFlow_.getAddress();
    const rewardAddress = await chunkLinearReward_.getAddress();
    const marketAddress = await fixedPriceMarket_.getAddress();
    const mineAddress = await poraMine_.getAddress();

    console.log(`initializing pora mine..`);
    if (!(await poraMine_.initialized())) {
        await (await poraMine_.initialize(config.mineConfigs.initDifficulty, flowAddress, rewardAddress)).wait();
    }

    console.log(`initializing fixed price market..`);
    if (!(await fixedPriceMarket_.initialized())) {
        await (await fixedPriceMarket_.initialize(config.lifetimeMonth, flowAddress, rewardAddress)).wait();
    }

    console.log(`initializing chunk linear reward..`);
    if (!(await chunkLinearReward_.initialized())) {
        await (await chunkLinearReward_.initialize(marketAddress, mineAddress)).wait();
    }

    console.log(`initializing fixed price flow..`);
    if (!(await fixedPriceFlow_.initialized())) {
        await (await fixedPriceFlow_.initialize(marketAddress)).wait();
    }
    console.log(`all contract initialized.`);
};

deploy.tags = ["market-enabled"];
deploy.dependencies = [
    CONTRACTS.PoraMine.name,
    CONTRACTS.ChunkLinearReward.name,
    CONTRACTS.FixedPriceMarket.name,
    CONTRACTS.FixedPriceFlow.name,
];
export default deploy;
