import { ZeroAddress } from "ethers";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConfig } from "../config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // initialize all contracts
    const config = getConfig(hre.network.name);
    const poraMineTest_ = await getTypedContract(hre, CONTRACTS.PoraMineTest);
    const flow_ = await getTypedContract(hre, CONTRACTS.Flow);

    console.log(`initializing pora mine test..`);
    if (!(await poraMineTest_.initialized())) {
        await (
            await poraMineTest_.initialize(
                config.mineConfigs.initHashRate,
                config.mineConfigs.adjustRatio,
                await flow_.getAddress(),
                ZeroAddress
            )
        ).wait();
    }

    console.log(`initializing flow..`);
    if (!(await flow_.initialized())) {
        await (await flow_["initialize(address)"](ZeroAddress)).wait();
    }
    console.log(`all contract initialized.`);
};

deploy.tags = ["no-market"];
deploy.dependencies = [CONTRACTS.PoraMineTest.name, CONTRACTS.Flow.name];
export default deploy;
