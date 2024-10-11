import { task, types } from "hardhat/config";
import { UpgradeableBeacon } from "../../typechain-types";
import { transact, validateError } from "../utils/utils";
import { getProxyInfo } from "./access";

const CONSTRUCTOR_ARGS: { [key: string]: unknown[] } = {
    FixedPriceFlow: [0n, 0n],
    PoraMine: [0n],
    ChunkLinearReward: [0n],
};

task("upgrade", "upgrade contract")
    .addParam("name", "name of the proxy contract", undefined, types.string, false)
    .addParam("artifact", "name of the implementation contract", undefined, types.string, false)
    .addParam("execute", "settle transaction on chain", false, types.boolean, true)
    .setAction(async (taskArgs: { name: string; artifact: string; execute: boolean }, hre) => {
        const { deployments, getNamedAccounts } = hre;
        const { deployer } = await getNamedAccounts();
        const beacon: UpgradeableBeacon = await hre.ethers.getContract(`${taskArgs.name}Beacon`, deployer);
        const newImpl = await hre.ethers.getContractFactory(taskArgs.artifact);

        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-expect-error
        await hre.upgrades.validateUpgrade(await beacon.implementation(), newImpl, {
            unsafeAllow: ["constructor", "state-variable-immutable"],
            kind: "beacon",
            constructorArgs: taskArgs.artifact in CONSTRUCTOR_ARGS ? CONSTRUCTOR_ARGS[taskArgs.artifact] : [],
        });

        const result = await deployments.deploy(`${taskArgs.name}Impl`, {
            from: deployer,
            contract: taskArgs.artifact,
            args: [],
            log: true,
        });
        console.log(`new implementation deployed: ${result.address}`);

        await transact(beacon, "upgradeTo", [result.address], taskArgs.execute);
    });

task("upgrade:validate", "validate upgrade")
    .addParam("old", "name of the old contract", undefined, types.string, false)
    .addParam("new", "name of the new contract", undefined, types.string, false)
    .setAction(async (taskArgs: { old: string; new: string }, hre) => {
        const oldAddr = await (await hre.ethers.getContract(`${taskArgs.old}Impl`)).getAddress();
        const newImpl = await hre.ethers.getContractFactory(taskArgs.new);
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-expect-error
        await hre.upgrades.validateUpgrade(oldAddr, newImpl, {
            unsafeAllow: ["constructor", "state-variable-immutable"],
            kind: "beacon",
            constructorArgs: taskArgs.old in CONSTRUCTOR_ARGS ? CONSTRUCTOR_ARGS[taskArgs.old] : [],
        });
    });

task("upgrade:forceImport", "import contracts")
    .addParam("name", "name of the contract", undefined, types.string, false)
    .setAction(async (taskArgs: { name: string }, hre) => {
        const addr = await (await hre.ethers.getContract(`${taskArgs.name}Impl`)).getAddress();
        const factory = await hre.ethers.getContractFactory(taskArgs.name);
        await hre.upgrades.forceImport(addr, factory, {
            kind: "beacon",
            // eslint-disable-next-line @typescript-eslint/ban-ts-comment
            // @ts-expect-error
            constructorArgs: taskArgs.name in CONSTRUCTOR_ARGS ? CONSTRUCTOR_ARGS[taskArgs.name] : [],
        });
    });

task("upgrade:forceImportAll", "import contracts").setAction(async (_taskArgs, hre) => {
    const proxied = await getProxyInfo(hre);
    for (const name of Array.from(proxied)) {
        const addr = await (await hre.ethers.getContract(`${name}Impl`)).getAddress();
        const factory = await hre.ethers.getContractFactory(name);
        try {
            await hre.upgrades.forceImport(addr, factory, {
                kind: "beacon",
                // eslint-disable-next-line @typescript-eslint/ban-ts-comment
                // @ts-expect-error
                constructorArgs: name in CONSTRUCTOR_ARGS ? CONSTRUCTOR_ARGS[name] : [],
            });
            console.log(`force imported ${name}.`);
        } catch (e) {
            validateError(e, "The following deployment clashes with an existing one at");
            console.log(`${name} already imported.`);
        }
    }
});
