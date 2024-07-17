import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConfig } from "../config";
import { CONTRACTS, deployDirectly, getTypedContract } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const config = getConfig(hre.network.name);
    // deploy dummy contracts
    console.log(`deploying dummy market and reward..`);
    await deployDirectly(hre, CONTRACTS.DummyMarket);
    await deployDirectly(hre, CONTRACTS.DummyReward);
    // initialize all contracts
    const poraMineTest_ = await getTypedContract(hre, CONTRACTS.PoraMineTest);
    const flow_ = await getTypedContract(hre, CONTRACTS.Flow);
    const dummyMarket_ = await getTypedContract(hre, CONTRACTS.DummyMarket);
    const dummyReward_ = await getTypedContract(hre, CONTRACTS.DummyReward);

    console.log(`initializing pora mine test..`);
    if (!(await poraMineTest_.initialized())) {
        await (
            await poraMineTest_.initialize(
                config.mineConfigs.initDifficulty,
                await flow_.getAddress(),
                await dummyReward_.getAddress()
            )
        ).wait();
    }

    console.log(`initializing flow..`);
    if (!(await flow_.initialized())) {
        await (await flow_.initialize(await dummyMarket_.getAddress())).wait();
    }
    console.log(`all contract initialized.`);
};

deploy.tags = ["no-market"];
deploy.dependencies = [CONTRACTS.PoraMineTest.name, CONTRACTS.Flow.name];
export default deploy;
