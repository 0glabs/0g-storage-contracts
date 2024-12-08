import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConstructorArgs } from "../utils/constructor_args";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployInBeaconProxy(
        hre,
        CONTRACTS.OnePoolReward,
        getConstructorArgs(hre.network.name, CONTRACTS.OnePoolReward.name)
    );
};

deploy.tags = [CONTRACTS.OnePoolReward.name];
deploy.dependencies = [];
export default deploy;
