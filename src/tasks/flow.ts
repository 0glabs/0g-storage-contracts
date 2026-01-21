import { task, types } from "hardhat/config";
import { getConfig } from "../config";
import { CONTRACTS, getTypedContract } from "../utils/utils";
import { UpgradeableBeacon } from "../../typechain-types";

task("flow:show", "show contract params").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    // const signer = await hre.ethers.getSigner((await hre.getNamedAccounts()).deployer);
    // testnet turbo first impl
    // const flow = CONTRACTS.FixedPriceFlow.factory.connect("0x61450afb8F99AB3D614a45cb563C61f59d9DD026", signer);
    // testnet standard first impl
    // const flow = CONTRACTS.FixedPriceFlow.factory.connect("0x1F7A30Cd62c4132B6C521B8F79e7aE0046A4F307", signer);
    console.log(await flow.getContext());
    console.log(await flow.blocksPerEpoch());
    console.log(await flow.firstBlock());
    console.log(await flow.rootHistory());
});

task("flow:setparams", "set contract params").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    const config = getConfig(hre.network.name);
    await (await flow.setParams(config.blocksPerEpoch, config.firstBlock, config.rootHistory)).wait();
    console.log(`done.`);
});

task("flow:pause", "pause contract").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    await (await flow.pause()).wait();
    console.log(`done.`);
});

task("flow:unpause", "unpause contract").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    await (await flow.unpause()).wait();
    console.log(`done.`);
});

task("flow:updatecontext", "update context to latest").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    for (;;) {
        const before = await flow.epoch();
        await (await flow.makeContextFixedTimes(100)).wait();
        const after = await flow.epoch();
        if (after === before) {
            break;
        }
        console.log(`updated epoch to ${after}.`);
    }
    console.log(`done.`);
});

task("flow:setAdmin", "Set a new admin for the flow contract")
    .addParam("admin", "New admin address", undefined, types.string, false)
    .addOptionalParam("key", "Private key to use (defaults to deployer)", undefined, types.string)
    .setAction(async (taskArgs: { admin: string; key?: string }, hre) => {
        console.log(`Setting new admin for flow contract to: ${taskArgs.admin}`);

        // Validate admin address
        if (!hre.ethers.isAddress(taskArgs.admin)) {
            throw new Error(`Invalid admin address: ${taskArgs.admin}`);
        }

        let signer;
        if (taskArgs.key) {
            signer = new hre.ethers.Wallet(taskArgs.key, hre.ethers.provider);
            console.log(`Using provided private key, signer address: ${await signer.getAddress()}`);
        } else {
            const { deployer } = await hre.getNamedAccounts();
            signer = await hre.ethers.getSigner(deployer);
            console.log(`Using deployer address: ${deployer}`);
        }

        const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow, signer);
        const contractAddress = await flow.getAddress();
        console.log(`FixedPriceFlow contract address: ${contractAddress}`);

        try {
            // Check if signer hash PAUSE_ROLE
            const PAUSE_ROLE = await flow.PAUSER_ROLE();
            const signerAddress = await signer.getAddress();
            const hasPauseRole = await flow.hasRole(PAUSE_ROLE, signerAddress);

            if (!hasPauseRole) {
                throw new Error(`Signer ${signerAddress} does not have PAUSE_ROLE`);
            }

            // Grant PAUSE_ROLE to new admin
            console.log(`Granting PAUSE_ROLE to ${taskArgs.admin}...`);
            const pauseTx = await flow.grantRole(PAUSE_ROLE, taskArgs.admin);
            console.log(`Grant transaction sent: ${pauseTx.hash}`);

            const pauseReceipt = await pauseTx.wait();
            if (!pauseReceipt) {
                throw new Error("Grant transaction receipt is null");
            }
            console.log(`Grant transaction confirmed in block: ${pauseReceipt.blockNumber}`);

            // Revoke DEFAULT_PAUSE_ROLEADMIN_ROLE from old admin
            console.log(`Revoking PAUSE_ROLE from ${signerAddress}...`);
            const revokePauseTx = await flow.revokeRole(PAUSE_ROLE, signerAddress);
            console.log(`Revoke transaction sent: ${revokePauseTx.hash}`);

            const revokePauseReceipt = await revokePauseTx.wait();
            if (!revokePauseReceipt) {
                throw new Error("Revoke transaction receipt is null");
            }
            console.log(`Revoke transaction confirmed in block: ${revokePauseReceipt.blockNumber}`);

            // Check if signer has DEFAULT_ADMIN_ROLE
            const DEFAULT_ADMIN_ROLE = await flow.DEFAULT_ADMIN_ROLE();
            const hasAdminRole = await flow.hasRole(DEFAULT_ADMIN_ROLE, signerAddress);

            if (!hasAdminRole) {
                throw new Error(`Signer ${signerAddress} does not have DEFAULT_ADMIN_ROLE`);
            }

            // Grant DEFAULT_ADMIN_ROLE to new admin
            console.log(`Granting DEFAULT_ADMIN_ROLE to ${taskArgs.admin}...`);
            const grantTx = await flow.grantRole(DEFAULT_ADMIN_ROLE, taskArgs.admin);
            console.log(`Grant transaction sent: ${grantTx.hash}`);

            const grantReceipt = await grantTx.wait();
            if (!grantReceipt) {
                throw new Error("Grant transaction receipt is null");
            }
            console.log(`Grant transaction confirmed in block: ${grantReceipt.blockNumber}`);

            // Revoke DEFAULT_ADMIN_ROLE from old admin
            console.log(`Revoking DEFAULT_ADMIN_ROLE from ${signerAddress}...`);
            const revokeTx = await flow.revokeRole(DEFAULT_ADMIN_ROLE, signerAddress);
            console.log(`Revoke transaction sent: ${revokeTx.hash}`);

            const revokeReceipt = await revokeTx.wait();
            if (!revokeReceipt) {
                throw new Error("Revoke transaction receipt is null");
            }
            console.log(`Revoke transaction confirmed in block: ${revokeReceipt.blockNumber}`);

            // Verify the changes
            const hasNewDefaultAdminRole = await flow.hasRole(DEFAULT_ADMIN_ROLE, taskArgs.admin);
            const oldAdminRevokedDefault = !(await flow.hasRole(DEFAULT_ADMIN_ROLE, signerAddress));
            const hasNewPauseRole = await flow.hasRole(PAUSE_ROLE, taskArgs.admin);
            const oldPauseRevoked = !(await flow.hasRole(PAUSE_ROLE, signerAddress));

            if (hasNewDefaultAdminRole && oldAdminRevokedDefault && hasNewPauseRole && oldPauseRevoked) {
                console.log(`✅ Successfully transferred PAUSE_ROLE and DEFAULT_ADMIN_ROLE to ${taskArgs.admin}`);
            } else {
                console.log(`⚠️  Admin transfer completed but verification shows:`);
                console.log(`  - DEFAULT_ADMIN_ROLE: ${hasNewDefaultAdminRole ? "✓" : "✗"}`);
                console.log(`  - Old admin revoked: ${oldAdminRevokedDefault ? "✓" : "✗"}`);
            }
        } catch (error: any) {
            console.error(`❌ Failed to set admin: ${error.message}`);
            throw error;
        }
    });

task("flow:transfer-beacon-ownership", "transfer beacon contract ownership")
    .addParam("newOwner", "new owner address", undefined, types.string, false)
    .addParam("execute", "execute the transfer", false, types.boolean, true)
    .setAction(async (taskArgs: { newOwner: string; execute: boolean }, hre) => {
        const beaconContract = await hre.ethers.getContract("FixedPriceFlowBeacon");
        const beacon = beaconContract as UpgradeableBeacon;
        
        const currentOwner = await beacon.owner();
        console.log(`Current owner: ${currentOwner}`);
        console.log(`New owner: ${taskArgs.newOwner}`);
        
        if (taskArgs.execute) {
            console.log("Transferring beacon ownership...");
            const tx = await beacon.transferOwnership(taskArgs.newOwner);
            await tx.wait();
            console.log(`Ownership transferred! Transaction hash: ${tx.hash}`);
            
            const newOwner = await beacon.owner();
            console.log(`New owner confirmed: ${newOwner}`);
        } else {
            console.log("Dry run complete. Use --execute true to perform the transfer.");
            console.log(`Transfer call: beacon.transferOwnership("${taskArgs.newOwner}")`);
        }
    });