import { task, types } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { AccessControl, AccessControlEnumerable, UpgradeableBeacon } from "../../typechain-types";
import {
    AnyContractMeta,
    CONTRACTS,
    DEFAULT_ADMIN_ROLE,
    getTypedContract,
    PAUSER_ROLE,
    validateError,
} from "../utils/utils";

export async function getProxyInfo(hre: HardhatRuntimeEnvironment) {
    const proxied = new Set<string>();
    for (const contractMeta of Object.values(CONTRACTS)) {
        const name = contractMeta.name;
        try {
            await hre.ethers.getContract(`${name}Beacon`);
            proxied.add(name);
        } catch (e) {
            validateError(e, "No Contract deployed with name");
        }
    }
    return proxied;
}

task("access:upgrade", "transfer beacon ownership to timelock")
    .addParam("timelock", "timelock address", undefined, types.string, false)
    .setAction(async (taskArgs: { timelock: string }, hre) => {
        const { getNamedAccounts } = hre;
        const { deployer } = await getNamedAccounts();
        const proxied = await getProxyInfo(hre);
        for (const name of Array.from(proxied)) {
            const beacon: UpgradeableBeacon = await hre.ethers.getContract(`${name}Beacon`, deployer);
            if ((await beacon.owner()).toLowerCase() === deployer.toLowerCase()) {
                console.log(`transfer ownership of ${name}Beacon..`);
                await (await beacon.transferOwnership(taskArgs.timelock)).wait();
            }
        }
    });

task("access:admin", "grant default admin role to timelock")
    .addParam("timelock", "timelock address", undefined, types.string, false)
    .setAction(async (taskArgs: { timelock: string }, hre) => {
        const { getNamedAccounts } = hre;
        const { deployer } = await getNamedAccounts();
        for (const contractMeta of Object.values(CONTRACTS)) {
            const name = contractMeta.name;
            let contract: AccessControl;
            try {
                const anyContract = await getTypedContract(hre, contractMeta as AnyContractMeta);
                if (!anyContract.interface.hasFunction("DEFAULT_ADMIN_ROLE")) {
                    continue;
                }
                contract = anyContract as AccessControl;
            } catch (e) {
                validateError(e, "No Contract deployed with name");
                continue;
            }
            if (await contract.hasRole(DEFAULT_ADMIN_ROLE, deployer)) {
                console.log(`granting default admin role of ${name} to timelock..`);
                await (await contract.grantRole(DEFAULT_ADMIN_ROLE, taskArgs.timelock)).wait();
            } else {
                console.log(`deployer does not have default admin role of ${name}, skip.`);
            }
        }
    });

task("access:pauser", "grant pauser role to multisig")
    .addParam("multisig", "multisig address", undefined, types.string, false)
    .setAction(async (taskArgs: { multisig: string }, hre) => {
        const { getNamedAccounts } = hre;
        const { deployer } = await getNamedAccounts();
        for (const contractMeta of Object.values(CONTRACTS)) {
            const name = contractMeta.name;
            let contract: AccessControl;
            try {
                const anyContract = await getTypedContract(hre, contractMeta as AnyContractMeta);
                if (!anyContract.interface.hasFunction("PAUSER_ROLE")) {
                    continue;
                }
                contract = anyContract as AccessControl;
            } catch (e) {
                validateError(e, "No Contract deployed with name");
                continue;
            }
            if (await contract.hasRole(DEFAULT_ADMIN_ROLE, deployer)) {
                console.log(`granting pauser role of ${name} to multisig..`);
                await (await contract.grantRole(PAUSER_ROLE, taskArgs.multisig)).wait();
            } else {
                console.log(`deployer does not have default admin role of ${name}, skip.`);
            }
        }
    });

task("revoke:admin", "revoke admin role").setAction(async (_taskArgs, hre) => {
    const { getNamedAccounts } = hre;
    const { deployer } = await getNamedAccounts();
    for (const contractMeta of Object.values(CONTRACTS)) {
        const name = contractMeta.name;
        let contract: AccessControlEnumerable;
        try {
            const anyContract = await getTypedContract(hre, contractMeta as AnyContractMeta);
            if (!anyContract.interface.hasFunction("DEFAULT_ADMIN_ROLE")) {
                continue;
            }
            contract = anyContract as AccessControlEnumerable;
        } catch (e) {
            validateError(e, "No Contract deployed with name");
            continue;
        }
        if (await contract.hasRole(DEFAULT_ADMIN_ROLE, deployer)) {
            if ((await contract.getRoleMemberCount(DEFAULT_ADMIN_ROLE)) === 1n) {
                console.log(`deployer is the only admin of ${name}, skip.`);
                continue;
            }
            console.log(`renouncing deployer's default admin role of ${name}..`);
            await (await contract.renounceRole(DEFAULT_ADMIN_ROLE, deployer)).wait();
        } else {
            console.log(`deployer does not have default admin role of ${name}, skip.`);
        }
    }
});
