import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { CONTRACTS, deployDirectly } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployDirectly(hre, CONTRACTS.Blake2bTest);
};

deploy.tags = [CONTRACTS.Blake2bTest.name, "test"];
deploy.dependencies = [];
export default deploy;
