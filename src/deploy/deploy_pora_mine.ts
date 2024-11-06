import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";
import { getConstructorArgs } from "../utils/constructor_args";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployInBeaconProxy(hre, CONTRACTS.PoraMine, getConstructorArgs(hre.network.name, CONTRACTS.PoraMine.name));
};

deploy.tags = [CONTRACTS.PoraMine.name, "market-enabled"];
deploy.dependencies = [];
export default deploy;
