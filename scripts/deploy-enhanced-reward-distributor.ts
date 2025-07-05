import { ethers } from "hardhat";

interface DeploymentResult {
    zgsToken: string;
    rewardDistributor: string;
    operator: string;
}

async function main(): Promise<DeploymentResult> {
    console.log("🚀 Deploying ZGS Reward Distributor contract...");

    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying with account: ${deployer.address}`);

    // Get ZGS token address from environment variable
    const ZGS_TOKEN_ADDRESS = process.env.ZGS_TOKEN_ADDRESS;
    
    if (!ZGS_TOKEN_ADDRESS) {
        throw new Error("❌ ZGS_TOKEN_ADDRESS environment variable is required!");
    }

    console.log("📦 Using existing ZGS token...");
    console.log(`✅ ZGS token address: ${ZGS_TOKEN_ADDRESS}`);

    // Verify ZGS token contract exists
    try {
        const zgsToken = await ethers.getContractAt("ISafeERC20", ZGS_TOKEN_ADDRESS);
        const tokenName = await zgsToken.name();
        const tokenSymbol = await zgsToken.symbol();
        console.log(`✅ ZGS token verified: ${tokenName} (${tokenSymbol})`);
    } catch (error) {
        throw new Error(`❌ Invalid ZGS token address: ${ZGS_TOKEN_ADDRESS}`);
    }

    // Deploy the ZGS Reward Distributor contract
    console.log("📦 Deploying ZGS Reward Distributor...");
    const RewardDistributorSetup = await ethers.getContractFactory("RewardDistributorSetup");
    
    // Set operator as deployer for testing (replace with actual service address)
    const operator = deployer.address;
    
    const rewardDistributor = await RewardDistributorSetup.deploy(
        ZGS_TOKEN_ADDRESS,
        operator
    );
    await rewardDistributor.deployed();

    console.log(`✅ ZGS Reward Distributor deployed to: ${rewardDistributor.address}`);
    console.log(`🔑 Operator set to: ${operator}`);

    // Verify deployment
    console.log("\n📋 Deployment Summary:");
    console.log(`   ZGS Token: ${ZGS_TOKEN_ADDRESS}`);
    console.log(`   Reward Distributor: ${rewardDistributor.address}`);
    console.log(`   Operator: ${operator}`);

    // Get contract stats
    const stats = await rewardDistributor.getContractStats();
    console.log(`\n📊 Contract Stats:`);
    console.log(`   Current Merkle Root: ${stats[0]}`);
    console.log(`   Last Update Timestamp: ${stats[1]}`);

    console.log("\n🎉 Deployment completed successfully!");
    console.log("\n📝 Next steps:");
    console.log("   1. Update the contract address in your off-chain service");
    console.log("   2. Set up your Merkle tree generation service");
    console.log("   3. Configure the operator private key in your service");
    console.log("   4. Start processing daily reward updates");
    console.log("   5. Transfer ZGS tokens to the contract");

    return {
        zgsToken: ZGS_TOKEN_ADDRESS,
        rewardDistributor: rewardDistributor.address,
        operator: operator
    };
}

main()
    .then((result) => {
        console.log("\n📄 Deployment addresses for configuration:");
        console.log(`CONTRACT_ADDRESS="${result.rewardDistributor}"`);
        console.log(`ZGS_TOKEN_ADDRESS="${result.zgsToken}"`);
        console.log(`OPERATOR_ADDRESS="${result.operator}"`);
        process.exit(0);
    })
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    }); 