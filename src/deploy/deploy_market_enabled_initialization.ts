import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConfig } from "../config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // initialize all contracts
    const config = getConfig(hre.network.name);
    const poraMine_ = await getTypedContract(hre, CONTRACTS.PoraMine);
    const fixedPriceMarket_ = await getTypedContract(hre, CONTRACTS.FixedPrice);
    const chunkLinearReward_ = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);
    const fixedPriceFlow_ = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);

    const flowAddress = await fixedPriceFlow_.getAddress();
    const rewardAddress = await chunkLinearReward_.getAddress();
    const marketAddress = await fixedPriceMarket_.getAddress();
    const mineAddress = await poraMine_.getAddress();

    console.log(`initializing pora mine..`);
    await (
        await poraMine_.initialize(flowAddress, rewardAddress, {
            difficulty: config.mineConfigs.initDifficulty,
            targetMineBlocks: config.mineConfigs.targetMineBlocks,
            targetSubmissions: config.mineConfigs.targetSubmissions,
            maxShards: config.mineConfigs.maxShards,
            nSubtasks: config.mineConfigs.nSubtasks,
            subtaskInterval: config.mineConfigs.subtaskInterval,
        })
    ).wait();

    console.log(`initializing fixed price market..`);
    // Use `lifetimeMonth * MONTH_ZGAS_UNITS_PER_SECTOR` as `pricePerSector`
    await (
        await fixedPriceMarket_.initialize(
            (BigInt(config.lifetimeMonth * config.unitPrice) * 1_000_000_000_000_000_000n) /
                1024n /
                1024n /
                1024n /
                12n,
            flowAddress,
            rewardAddress
        )
    ).wait();

    console.log(`initializing chunk linear reward..`);
    await (
        await chunkLinearReward_.initialize(marketAddress, mineAddress, config.chunkRewardConfigs.foundationAdmin)
    ).wait();

    console.log(`initializing fixed price flow..`);
    await (await fixedPriceFlow_.initialize(marketAddress, config.blocksPerEpoch)).wait();
    console.log(`all contract initialized.`);
};

deploy.tags = ["market-enabled"];
deploy.dependencies = [
    CONTRACTS.PoraMine.name,
    CONTRACTS.ChunkLinearReward.name,
    CONTRACTS.FixedPrice.name,
    CONTRACTS.FixedPriceFlow.name,
];
export default deploy;
