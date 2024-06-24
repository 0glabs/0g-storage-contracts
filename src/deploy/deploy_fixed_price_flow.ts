import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConfig } from "../config";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const config = getConfig(hre.network.name);
    await deployInBeaconProxy(hre, CONTRACTS.FixedPriceFlow, [config.blocksPerEpoch, config.flowDeployDelay]);
};

deploy.tags = [CONTRACTS.FixedPriceFlow.name, "market-enabled"];
deploy.dependencies = [];
export default deploy;
