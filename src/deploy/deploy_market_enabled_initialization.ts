import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConfig } from "../config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // initialize all contracts
    const config = getConfig(hre.network.name);
    const poraMine_ = await getTypedContract(hre, CONTRACTS.PoraMine);
    const fixedPrice_ = await getTypedContract(hre, CONTRACTS.FixedPrice);
    const onePoolReward_ = await getTypedContract(hre, CONTRACTS.OnePoolReward);
    const fixedPriceFlow_ = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);

    console.log(`initializing pora mine..`);
    if (!(await poraMine_.initialized())) {
        await (
            await poraMine_.initialize(
                config.mineConfigs.initHashRate,
                config.mineConfigs.adjustRatio,
                await fixedPriceFlow_.getAddress(),
                await onePoolReward_.getAddress()
            )
        ).wait();
    }

    console.log(`initializing fixed price market..`);
    if (!(await fixedPrice_.initialized())) {
        await (
            await fixedPrice_.initialize(
                config.lifetimeMonth,
                await fixedPriceFlow_.getAddress(),
                await onePoolReward_.getAddress()
            )
        ).wait();
    }

    console.log(`initializing one pool reward..`);
    if (!(await onePoolReward_.initialized())) {
        await (await onePoolReward_.initialize(await fixedPrice_.getAddress(), await poraMine_.getAddress())).wait();
    }

    console.log(`initializing fixed price flow..`);
    if (!(await fixedPriceFlow_.initialized())) {
        await (await fixedPriceFlow_["initialize(address)"](await fixedPrice_.getAddress())).wait();
    }
    console.log(`all contract initialized.`);
};

deploy.tags = ["market-enabled"];
deploy.dependencies = [
    CONTRACTS.PoraMine.name,
    CONTRACTS.OnePoolReward.name,
    CONTRACTS.FixedPrice.name,
    CONTRACTS.FixedPriceFlow.name,
];
export default deploy;
