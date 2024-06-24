import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConfig } from "../config";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const config = getConfig(hre.network.name);
    await deployInBeaconProxy(hre, CONTRACTS.Flow, [config.blocksPerEpoch, config.flowDeployDelay]);
};

deploy.tags = [CONTRACTS.Flow.name, "no-market"];
deploy.dependencies = [];
export default deploy;
