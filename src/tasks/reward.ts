import { task, types } from "hardhat/config";
import { CONTRACTS, getTypedContract } from "../utils/utils";
import { UpgradeableBeacon } from "../../typechain-types";

task("reward:donate", "set extra total base reward")
    .addParam("amnt", "amount of donation", undefined, types.string, false)
    .setAction(async (taskArgs: { amnt: string }, hre) => {
        const reward = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);
        await (await reward.donate({ value: hre.ethers.parseEther(taskArgs.amnt) })).wait();
        console.log(`donated ${taskArgs.amnt}`);
    });

task("reward:setBaseReward", "set extra base reward")
    .addParam("amnt", "amount of base reward", undefined, types.string, false)
    .setAction(async (taskArgs: { amnt: string }, hre) => {
        const reward = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);
        await (await reward.setBaseReward(hre.ethers.parseEther(taskArgs.amnt))).wait();
        console.log(`set base reward to ${taskArgs.amnt}`);
    });

task("reward:beacon-owner", "check beacon contract owner")
    .setAction(async (_taskArgs, hre) => {
        const beaconContract = await hre.ethers.getContract("ChunkLinearRewardBeacon");
        const beacon = beaconContract as UpgradeableBeacon;
        const beaconAddress = await beacon.getAddress();
        
        const owner = await beacon.owner();
        console.log(`Beacon contract: ${beaconAddress}`);
        console.log(`Current owner: ${owner}`);
        
        const [signer] = await hre.ethers.getSigners();
        const signerAddress = await signer.getAddress();
        console.log(`Your address: ${signerAddress}`);
        console.log(`You are the owner: ${owner.toLowerCase() === signerAddress.toLowerCase()}`);
    });

task("reward:transfer-beacon-ownership", "transfer beacon contract ownership")
    .addParam("newOwner", "new owner address", undefined, types.string, false)
    .addParam("execute", "execute the transfer", false, types.boolean, true)
    .setAction(async (taskArgs: { newOwner: string; execute: boolean }, hre) => {
        const beaconContract = await hre.ethers.getContract("ChunkLinearRewardBeacon");
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

task("reward:upgrade", "Deploy new ChunkLinearReward implementation and upgrade beacon")
    .addOptionalParam("key", "Private key to use (defaults to deployer)", undefined, types.string)
    .setAction(async (taskArgs: { key?: string }, hre) => {
        console.log(`🔄 Upgrading ChunkLinearReward contract on network: ${hre.network.name}`);

        let signer;
        if (taskArgs.key) {
            signer = new hre.ethers.Wallet(taskArgs.key, hre.ethers.provider);
            console.log(`Using provided private key, signer address: ${await signer.getAddress()}`);
        } else {
            const { deployer } = await hre.getNamedAccounts();
            signer = await hre.ethers.getSigner(deployer);
            console.log(`Using deployer address: ${deployer}`);
        }

        try {
            // Get the beacon contract with proper typing
            const beaconContract = await hre.ethers.getContract("ChunkLinearRewardBeacon");
            const beacon = beaconContract as UpgradeableBeacon;
            const beaconAddress = await beacon.getAddress();
            console.log(`📡 Beacon contract address: ${beaconAddress}`);

            // Get current implementation
            const currentImpl = await beacon.implementation();
            console.log(`📋 Current implementation: ${currentImpl}`);

            // Check if signer is the owner of the beacon
            const owner = await beacon.owner();
            const signerAddress = await signer.getAddress();
            
            if (owner.toLowerCase() !== signerAddress.toLowerCase()) {
                throw new Error(`❌ Signer ${signerAddress} is not the owner of the beacon. Owner is: ${owner}`);
            }

            console.log("🏗️  Deploying new implementation...");
            
            // Deploy new implementation with hardhat-deploy
            const { deployments } = hre;
            const releaseSeconds = "32140800"; // Keep the same releaseSeconds
            
            const result = await deployments.deploy(`ChunkLinearRewardImpl`, {
                from: await signer.getAddress(),
                contract: CONTRACTS.ChunkLinearReward.contractName(),
                args: [releaseSeconds],
                log: true,
            });

            const newImplAddress = result.address;
            console.log(`🆕 New implementation deployed: ${newImplAddress}`);

            if (currentImpl.toLowerCase() === newImplAddress.toLowerCase()) {
                console.log("⚠️  Implementation is already up to date!");
                return;
            }

            console.log("🚀 Sending upgrade transaction...");
            const tx = await beacon.connect(signer).upgradeTo(newImplAddress);
            console.log(`📝 Transaction hash: ${tx.hash}`);

            const receipt = await tx.wait();
            if (!receipt) {
                throw new Error("Transaction receipt is null");
            }

            console.log(`✅ Upgrade completed in block: ${receipt.blockNumber}`);
            console.log(`⛽ Gas used: ${receipt.gasUsed.toString()}`);

            // Verify the upgrade
            const updatedImpl = await beacon.implementation();
            console.log(`🔍 Verified new implementation: ${updatedImpl}`);

            if (updatedImpl.toLowerCase() === newImplAddress.toLowerCase()) {
                console.log("🎉 ChunkLinearReward contract successfully upgraded!");
                console.log(`📋 Old implementation: ${currentImpl}`);
                console.log(`🆕 New implementation: ${newImplAddress}`);
            } else {
                console.log("❌ Upgrade verification failed!");
            }

        } catch (error) {
            console.error("❌ Upgrade failed:", error);
            throw error;
        }
    });

