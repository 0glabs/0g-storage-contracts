import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConstructorArgs } from "../utils/constructor_args";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployInBeaconProxy(
        hre,
        CONTRACTS.ChunkLinearReward,
        getConstructorArgs(hre.network.name, CONTRACTS.ChunkLinearReward.name)
    );
};

deploy.tags = [CONTRACTS.ChunkLinearReward.name, "market-enabled"];
deploy.dependencies = [];
export default deploy;
