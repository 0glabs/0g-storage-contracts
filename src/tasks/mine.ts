import { task, types } from "hardhat/config";
import { UpgradeableBeacon } from "../../typechain-types";
import { CONTRACTS, getTypedContract } from "../utils/utils";

task("mine:show", "show contract params").setAction(async (_, hre) => {
    const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
    const [
        targetSubmissions,
        targetSubmissionsNextEpoch,
        targetMineBlocks,
        poraTarget,
        minDifficulty,
        nSubtasks,
        nSubtasksNextEpoch,
        subtaskInterval,
        subtaskIntervalNextEpoch,
        currentSubmissions,
        lastMinedEpoch,
        maxShards,
        difficultyAdjustRatio,
        canSubmit,
        flow,
        reward,
    ] = await Promise.all([
        mine.targetSubmissions(),
        mine.targetSubmissionsNextEpoch(),
        mine.targetMineBlocks(),
        mine.poraTarget(),
        mine.minDifficulty(),
        mine.nSubtasks(),
        mine.nSubtasksNextEpoch(),
        mine.subtaskInterval(),
        mine.subtaskIntervalNextEpoch(),
        mine.currentSubmissions(),
        mine.lastMinedEpoch(),
        mine.maxShards(),
        mine.difficultyAdjustRatio(),
        mine.canSubmit.staticCall(),
        mine.flow(),
        mine.reward(),
    ]);

    console.log(`targetSubmissions: ${targetSubmissions.toString()}`);
    console.log(`targetSubmissionsNextEpoch: ${targetSubmissionsNextEpoch.toString()}`);
    console.log(`targetMineBlocks: ${targetMineBlocks.toString()}`);
    console.log(`poraTarget: ${poraTarget.toString()}`);
    console.log(`minDifficulty: ${minDifficulty.toString()}`);
    console.log(`nSubtasks: ${nSubtasks.toString()}`);
    console.log(`nSubtasksNextEpoch: ${nSubtasksNextEpoch.toString()}`);
    console.log(`subtaskInterval: ${subtaskInterval.toString()}`);
    console.log(`subtaskIntervalNextEpoch: ${subtaskIntervalNextEpoch.toString()}`);
    console.log(`currentSubmissions: ${currentSubmissions.toString()}`);
    console.log(`lastMinedEpoch: ${lastMinedEpoch.toString()}`);
    console.log(`maxShards: ${maxShards.toString()}`);
    console.log(`difficultyAdjustRatio: ${difficultyAdjustRatio.toString()}`);
    console.log(`canSubmit: ${canSubmit}`);
    console.log(`flow: ${flow}`);
    console.log(`reward: ${reward}`);
});

task("mine:setTargetSubmissions", "set target submissions")
    .addParam("n", "number of target submissions", undefined, types.int, false)
    .setAction(async (taskArgs: { n: number }, hre) => {
        const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
        await (await mine.setTargetSubmissions(taskArgs.n)).wait();
        console.log(`set target submission to ${taskArgs.n}`);
    });

task("mine:setMinDifficulty", "set min difficulty")
    .addParam("min", "number of min difficulty", undefined, types.bigint, false)
    .setAction(async (taskArgs: { min: bigint }, hre) => {
        const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
        await (await mine.setMinDifficulty(taskArgs.min)).wait();
        console.log(`set min difficulty to ${taskArgs.min.toString()}`);
    });

task("mine:setNumSubtasks", "set num subtasks")
    .addParam("n", "number of num subtasks", undefined, types.int, false)
    .setAction(async (taskArgs: { n: number }, hre) => {
        const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
        await (await mine.setNumSubtasks(taskArgs.n)).wait();
        console.log(`set num subtasks to ${taskArgs.n}`);
    });

task("mine:setAdmin", "Set a new admin for the mine contract")
    .addParam("admin", "New admin address", undefined, types.string, false)
    .addOptionalParam("key", "Private key to use (defaults to deployer)", undefined, types.string)
    .setAction(async (taskArgs: { admin: string; key?: string }, hre) => {
        console.log(`Setting new admin for mine contract to: ${taskArgs.admin}`);

        // Validate admin address
        if (!hre.ethers.isAddress(taskArgs.admin)) {
            throw new Error(`Invalid admin address: ${String(taskArgs.admin)}`);
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

        const mine = await getTypedContract(hre, CONTRACTS.PoraMine, signer);
        const contractAddress = await mine.getAddress();
        console.log(`PoraMine contract address: ${contractAddress}`);

        try {
            // Check if signer hash PARAMS_ADMIN_ROLE
            const PARAMS_ADMIN_ROLE = await mine.PARAMS_ADMIN_ROLE();
            const signerAddress = await signer.getAddress();
            const hasParamsAdminRole = await mine.hasRole(PARAMS_ADMIN_ROLE, signerAddress);

            if (!hasParamsAdminRole) {
                throw new Error(`Signer ${signerAddress} does not have PARAMS_ADMIN_ROLE`);
            }

            // Grant PARAMS_ADMIN_ROLE to new admin
            console.log(`Granting PARAMS_ADMIN_ROLE to ${taskArgs.admin}...`);
            const paramTx = await mine.grantRole(PARAMS_ADMIN_ROLE, taskArgs.admin);
            console.log(`Grant transaction sent: ${paramTx.hash}`);

            const paramReceipt = await paramTx.wait();
            if (!paramReceipt) {
                throw new Error("Grant transaction receipt is null");
            }
            console.log(`Grant transaction confirmed in block: ${paramReceipt.blockNumber}`);

            // Revoke PARAMS_ADMIN_ROLE from old admin
            console.log(`Revoking PARAMS_ADMIN_ROLE from ${signerAddress}...`);
            const revokeParamTx = await mine.revokeRole(PARAMS_ADMIN_ROLE, signerAddress);
            console.log(`Revoke transaction sent: ${revokeParamTx.hash}`);

            const revokeParamReceipt = await revokeParamTx.wait();
            if (!revokeParamReceipt) {
                throw new Error("Revoke transaction receipt is null");
            }
            console.log(`Revoke transaction confirmed in block: ${revokeParamReceipt.blockNumber}`);

            // Check if signer has DEFAULT_ADMIN_ROLE
            const DEFAULT_ADMIN_ROLE = await mine.DEFAULT_ADMIN_ROLE();
            const hasAdminRole = await mine.hasRole(DEFAULT_ADMIN_ROLE, signerAddress);

            if (!hasAdminRole) {
                throw new Error(`Signer ${signerAddress} does not have DEFAULT_ADMIN_ROLE`);
            }

            // Grant DEFAULT_ADMIN_ROLE to new admin
            console.log(`Granting DEFAULT_ADMIN_ROLE to ${taskArgs.admin}...`);
            const grantTx = await mine.grantRole(DEFAULT_ADMIN_ROLE, taskArgs.admin);
            console.log(`Grant transaction sent: ${grantTx.hash}`);

            const grantReceipt = await grantTx.wait();
            if (!grantReceipt) {
                throw new Error("Grant transaction receipt is null");
            }
            console.log(`Grant transaction confirmed in block: ${grantReceipt.blockNumber}`);

            // Revoke DEFAULT_ADMIN_ROLE from old admin
            console.log(`Revoking DEFAULT_ADMIN_ROLE from ${signerAddress}...`);
            const revokeTx = await mine.revokeRole(DEFAULT_ADMIN_ROLE, signerAddress);
            console.log(`Revoke transaction sent: ${revokeTx.hash}`);

            const revokeReceipt = await revokeTx.wait();
            if (!revokeReceipt) {
                throw new Error("Revoke transaction receipt is null");
            }
            console.log(`Revoke transaction confirmed in block: ${revokeReceipt.blockNumber}`);

            // Verify the changes
            const hasNewDefaultAdminRole = await mine.hasRole(DEFAULT_ADMIN_ROLE, taskArgs.admin);
            const oldAdminRevokedDefault = !(await mine.hasRole(DEFAULT_ADMIN_ROLE, signerAddress));
            const hasNewParamsAdminRole = await mine.hasRole(PARAMS_ADMIN_ROLE, taskArgs.admin);
            const oldAdminRevokedParams = !(await mine.hasRole(PARAMS_ADMIN_ROLE, signerAddress));

            if (hasNewDefaultAdminRole && oldAdminRevokedDefault && hasNewParamsAdminRole && oldAdminRevokedParams) {
                console.log(
                    `✅ Successfully transferred PARAMS_ADMIN_ROLE and DEFAULT_ADMIN_ROLE to ${taskArgs.admin}`
                );
            } else {
                console.log(`⚠️  Admin transfer completed but verification shows:`);
                console.log(`  - DEFAULT_ADMIN_ROLE: ${hasNewDefaultAdminRole ? "✓" : "✗"}`);
                console.log(`  - Old admin revoked: ${oldAdminRevokedDefault ? "✓" : "✗"}`);
            }
        } catch (error: unknown) {
            const errorMessage = error instanceof Error ? error.message : String(error);
            console.error(`❌ Failed to set admin: ${errorMessage}`);
            throw error;
        }
    });

task("mine:transfer-beacon-ownership", "transfer beacon contract ownership")
    .addParam("newOwner", "new owner address", undefined, types.string, false)
    .addParam("execute", "execute the transfer", false, types.boolean, true)
    .setAction(async (taskArgs: { newOwner: string; execute: boolean }, hre) => {
        const beaconContract = await hre.ethers.getContract("PoraMineBeacon");
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
