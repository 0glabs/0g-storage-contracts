import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";
import { getConstructorArgs } from "../utils/constructor_args";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployInBeaconProxy(hre, CONTRACTS.Flow, getConstructorArgs(hre.network.name, CONTRACTS.Flow.name));
};

deploy.tags = [CONTRACTS.Flow.name, "no-market"];
deploy.dependencies = [];
export default deploy;
