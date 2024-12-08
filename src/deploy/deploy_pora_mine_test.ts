import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getConstructorArgs } from "../utils/constructor_args";
import { CONTRACTS, deployInBeaconProxy } from "../utils/utils";

const deploy: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await deployInBeaconProxy(
        hre,
        CONTRACTS.PoraMineTest,
        getConstructorArgs(hre.network.name, CONTRACTS.PoraMineTest.name)
    );
};

deploy.tags = [CONTRACTS.PoraMineTest.name, "no-market"];
deploy.dependencies = [];
export default deploy;
