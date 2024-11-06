import * as fs from "fs";
import { task, types } from "hardhat/config";
import path from "path";
import { UpgradeableBeacon } from "../../typechain-types";
import { getConstructorArgs } from "../utils/constructor_args";
import { CONTRACTS, transact, validateError } from "../utils/utils";
import { getProxyInfo } from "./access";

task("upgrade", "upgrade contract")
    .addParam("name", "name of the proxy contract", undefined, types.string, false)
    .addParam("artifact", "name of the implementation contract", undefined, types.string, false)
    .addParam("execute", "settle transaction on chain", false, types.boolean, true)
    .setAction(async (taskArgs: { name: string; artifact: string; execute: boolean }, hre) => {
        const { deployments, getNamedAccounts } = hre;
        const { deployer } = await getNamedAccounts();
        const beacon: UpgradeableBeacon = await hre.ethers.getContract(`${taskArgs.name}Beacon`, deployer);

        const result = await deployments.deploy(`${taskArgs.name}Impl`, {
            from: deployer,
            contract: taskArgs.artifact,
            // eslint-disable-next-line @typescript-eslint/ban-ts-comment
            // @ts-expect-error
            // eslint-disable-next-line @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-member-access
            args: getConstructorArgs(hre.network.name, CONTRACTS[taskArgs.name].name),
            log: true,
        });
        console.log(`new implementation deployed: ${result.address}`);

        await transact(beacon, "upgradeTo", [result.address], taskArgs.execute);
    });

task("upgrade:validate", "validate upgrade")
    .addParam("old", "name of the old contract", undefined, types.string, false)
    .addParam("new", "artifact of the new contract", undefined, types.string, false)
    .setAction(async (taskArgs: { old: string; new: string }, hre) => {
        const oldAddr = await (await hre.ethers.getContract(`${taskArgs.old}Impl`)).getAddress();
        const newImpl = await hre.ethers.getContractFactory(taskArgs.new);
        const chainId = (await hre.ethers.provider.getNetwork()).chainId;
        const tmpFileName = `unknown-${chainId}.json`;
        const tmpFilePath = path.resolve(__dirname, `../../.openzeppelin/${tmpFileName}`);
        const fileName = `${hre.network.name}-${chainId}.json`;
        const filePath = path.resolve(__dirname, `../../.openzeppelin/${fileName}`);
        if (fs.existsSync(filePath)) {
            fs.copyFileSync(filePath, tmpFilePath);
        } else {
            throw Error(`network file ${filePath} not found!`);
        }
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-expect-error
        await hre.upgrades.validateUpgrade(oldAddr, newImpl, {
            unsafeAllow: ["constructor", "state-variable-immutable"],
            kind: "beacon",
            constructorArgs: getConstructorArgs(hre.network.name, taskArgs.new),
        });
        fs.rmSync(tmpFilePath);
    });

task("upgrade:forceImportAll", "import contracts").setAction(async (_taskArgs, hre) => {
    const proxied = await getProxyInfo(hre);
    const chainId = (await hre.ethers.provider.getNetwork()).chainId;
    const tmpFileName = `unknown-${chainId}.json`;
    const tmpFilePath = path.resolve(__dirname, `../../.openzeppelin/${tmpFileName}`);
    if (fs.existsSync(tmpFilePath)) {
        console.log(`removing tmp network file ${tmpFilePath}..`);
        fs.rmSync(tmpFilePath);
    }
    for (const name of Array.from(proxied)) {
        const addr = await (await hre.ethers.getContract(`${name}Impl`)).getAddress();
        const factory = await hre.ethers.getContractFactory(name);
        try {
            await hre.upgrades.forceImport(addr, factory, {
                kind: "beacon",
                // eslint-disable-next-line @typescript-eslint/ban-ts-comment
                // @ts-expect-error
                // eslint-disable-next-line @typescript-eslint/no-unsafe-argument, @typescript-eslint/no-unsafe-member-access
                constructorArgs: getConstructorArgs(hre.network.name, CONTRACTS[name].name),
            });
            console.log(`force imported ${name}.`);
        } catch (e) {
            validateError(e, "The following deployment clashes with an existing one at");
            console.log(`${name} already imported.`);
        }
    }
    if (fs.existsSync(tmpFilePath)) {
        const newFileName = `${hre.network.name}-${chainId}.json`;
        const newFilePath = path.resolve(__dirname, `../../.openzeppelin/${newFileName}`);
        console.log(`renaming tmp network file ${tmpFileName} to ${newFileName}..`);
        fs.renameSync(tmpFilePath, newFilePath);
    }
});
