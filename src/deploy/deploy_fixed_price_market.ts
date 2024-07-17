import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployInBeaconProxy(hre, CONTRACTS.FixedPriceMarket);
};

deploy.tags = [CONTRACTS.FixedPriceMarket.name, "market-enabled"];
deploy.dependencies = [];
export default deploy;
