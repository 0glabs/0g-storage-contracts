import { ethers } from "hardhat";
import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';

/**
 * GraphQL Reward Service - Off-chain calculation and on-chain distribution
 * This service demonstrates how to:
 * 1. Calculate rewards off-chain using GraphQL data
 * 2. Generate Merkle proofs for batch updates
 * 3. Submit incremental updates to the smart contract
 */

// Type definitions
interface UserActivityData {
    user: string;
    activity: number;
    storage: number;
}

interface Reward {
    user: string;
    totalReward: number;
    incrementalReward: number;
    epoch: number;
}

interface RewardUpdate {
    epoch: number;
    merkleRoot: string;
    totalRewardAmount: number;
    userCount: number;
    incrementalAmount: number;
}

interface UserRewardData {
    user: string;
    totalReward: number;
    epoch: number;
    proof: string[];
}

interface MerkleTreeResult {
    tree: MerkleTree;
    leaves: Buffer[];
    rewards: Reward[];
}

class GraphQLRewardService {
    private contractAddress: string;
    private operatorPrivateKey: string;
    private currentEpoch: number;
    private rewardHistory: Map<string, number>;

    constructor(contractAddress: string, operatorPrivateKey: string) {
        this.contractAddress = contractAddress;
        this.operatorPrivateKey = operatorPrivateKey;
        this.currentEpoch = 0;
        this.rewardHistory = new Map<string, number>();
    }

    /**
     * Simulate GraphQL query to get user activity data
     * In real implementation, this would query your GraphQL endpoint
     */
    async queryUserActivityData(epoch: number): Promise<UserActivityData[]> {
        // Simulate GraphQL query
        console.log(`Querying GraphQL for epoch ${epoch} user activity...`);
        
        // Mock data - replace with actual GraphQL query
        const mockData: UserActivityData[] = [
            { user: "0x1234567890123456789012345678901234567890", activity: 100, storage: 50 },
            { user: "0x2345678901234567890123456789012345678901", activity: 200, storage: 75 },
            { user: "0x3456789012345678901234567890123456789012", activity: 150, storage: 60 },
            // Add more users as needed
        ];

        return mockData;
    }

    /**
     * Calculate rewards based on user activity and storage
     * This is the core off-chain calculation logic
     */
    calculateRewards(userData: UserActivityData[], epoch: number): { rewards: Reward[], totalRewardAmount: number } {
        const rewards: Reward[] = [];
        let totalRewardAmount = 0;

        for (const data of userData) {
            // Calculate reward based on activity and storage
            const activityReward = data.activity * 10; // 10 tokens per activity point
            const storageReward = data.storage * 5;    // 5 tokens per storage unit
            const totalReward = activityReward + storageReward;

            // Get previous total reward for this user
            const previousTotal = this.rewardHistory.get(data.user) || 0;
            const incrementalReward = totalReward - previousTotal;

            if (incrementalReward > 0) {
                rewards.push({
                    user: data.user,
                    totalReward: totalReward,
                    incrementalReward: incrementalReward,
                    epoch: epoch
                });

                totalRewardAmount += incrementalReward;
                this.rewardHistory.set(data.user, totalReward);
            }
        }

        return { rewards, totalRewardAmount };
    }

    /**
     * Generate Merkle tree from reward data
     */
    generateMerkleTree(rewards: Reward[]): MerkleTreeResult {
        const leaves = rewards.map(reward => 
            keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
                ['address', 'uint256', 'uint256'],
                [reward.user, reward.totalReward, reward.epoch]
            ))
        );

        const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        return { tree, leaves, rewards };
    }

    /**
     * Generate Merkle proof for a specific user
     */
    generateProof(tree: MerkleTree, userIndex: number): string[] {
        return tree.getHexProof(tree.getLeaf(userIndex));
    }

    /**
     * Submit reward update to smart contract
     */
    async submitRewardUpdate(rewards: Reward[], merkleRoot: string, totalRewardAmount: number): Promise<{ epoch: number, rewards: Reward[], merkleRoot: string }> {
        const provider = ethers.provider;
        const wallet = new ethers.Wallet(this.operatorPrivateKey, provider);
        const contract = await ethers.getContractAt("RewardDistributorSetup", this.contractAddress);

        this.currentEpoch++;

        const update: RewardUpdate = {
            epoch: this.currentEpoch,
            merkleRoot: merkleRoot,
            totalRewardAmount: totalRewardAmount,
            userCount: rewards.length,
            incrementalAmount: totalRewardAmount
        };

        console.log(`Submitting GraphQL update for epoch ${this.currentEpoch}:`);
        console.log(`- Merkle Root: ${merkleRoot}`);
        console.log(`- Total Reward Amount: ${totalRewardAmount}`);
        console.log(`- User Count: ${rewards.length}`);

        const tx = await contract.connect(wallet).submitGraphQLUpdate(update);
        await tx.wait();

        console.log(`✅ Reward update submitted successfully! TX: ${tx.hash}`);
        return { epoch: this.currentEpoch, rewards, merkleRoot };
    }

    /**
     * Generate claim data for a specific user
     */
    generateUserClaimData(userAddress: string, rewards: Reward[], tree: MerkleTree): UserRewardData {
        const userReward = rewards.find(r => r.user.toLowerCase() === userAddress.toLowerCase());
        if (!userReward) {
            throw new Error(`No reward found for user ${userAddress}`);
        }

        const userIndex = rewards.findIndex(r => r.user.toLowerCase() === userAddress.toLowerCase());
        const proof = this.generateProof(tree, userIndex);

        return {
            user: userAddress,
            totalReward: userReward.totalReward,
            epoch: userReward.epoch,
            proof: proof
        };
    }

    /**
     * Main function to process daily reward updates
     */
    async processDailyRewardUpdate(): Promise<{ epoch: number, rewards: Reward[], merkleRoot: string } | undefined> {
        try {
            console.log("🔄 Starting daily reward update process...");

            // 1. Query GraphQL for user activity data
            const userData = await this.queryUserActivityData(this.currentEpoch + 1);

            // 2. Calculate rewards off-chain
            const { rewards, totalRewardAmount } = this.calculateRewards(userData, this.currentEpoch + 1);

            if (rewards.length === 0) {
                console.log("No new rewards to distribute");
                return;
            }

            // 3. Generate Merkle tree
            const { tree, leaves } = this.generateMerkleTree(rewards);
            const merkleRoot = tree.getHexRoot();

            // 4. Submit to smart contract
            const result = await this.submitRewardUpdate(rewards, merkleRoot, totalRewardAmount);

            console.log("✅ Daily reward update completed successfully!");
            console.log(`📊 Summary:`);
            console.log(`   - Epoch: ${result.epoch}`);
            console.log(`   - Users with rewards: ${rewards.length}`);
            console.log(`   - Total reward amount: ${totalRewardAmount}`);

            return result;

        } catch (error) {
            console.error("❌ Error processing daily reward update:", error);
            throw error;
        }
    }

    /**
     * Get claimable amount for a user
     */
    async getClaimableAmount(userAddress: string, totalReward: number, epoch: number, proof: string[]): Promise<number> {
        const provider = ethers.provider;
        const contract = await ethers.getContractAt("RewardDistributorSetup", this.contractAddress);

        const claimable = await contract.getClaimableAmount(userAddress, totalReward, epoch, proof);
        return claimable;
    }

    /**
     * Simulate user claiming rewards
     */
    async simulateUserClaim(userAddress: string, userPrivateKey: string): Promise<void> {
        const provider = ethers.provider;
        const wallet = new ethers.Wallet(userPrivateKey, provider);
        const contract = await ethers.getContractAt("RewardDistributorSetup", this.contractAddress);

        // Get user's reward data (in real implementation, this would come from your system)
        const userReward = this.rewardHistory.get(userAddress);
        if (!userReward) {
            console.log(`No rewards found for user ${userAddress}`);
            return;
        }

        // Generate claim data (this would be provided by your frontend/API)
        const claimData: UserRewardData = {
            user: userAddress,
            totalReward: userReward,
            epoch: this.currentEpoch,
            proof: [] // This would be generated by your system
        };

        console.log(`User ${userAddress} claiming rewards...`);
        const tx = await contract.connect(wallet).claimReward(claimData);
        await tx.wait();

        console.log(`✅ User claim successful! TX: ${tx.hash}`);
    }
}

/**
 * Example usage and demonstration
 */
async function main(): Promise<void> {
    // Configuration
    const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || "YOUR_CONTRACT_ADDRESS";
    const OPERATOR_PRIVATE_KEY = process.env.OPERATOR_PRIVATE_KEY || "YOUR_OPERATOR_PRIVATE_KEY";

    if (CONTRACT_ADDRESS === "YOUR_CONTRACT_ADDRESS" || OPERATOR_PRIVATE_KEY === "YOUR_OPERATOR_PRIVATE_KEY") {
        throw new Error("Please set CONTRACT_ADDRESS and OPERATOR_PRIVATE_KEY environment variables");
    }

    // Initialize service
    const rewardService = new GraphQLRewardService(CONTRACT_ADDRESS, OPERATOR_PRIVATE_KEY);

    // Process daily reward update
    console.log("🚀 Starting GraphQL-based reward distribution...");
    
    try {
        const result = await rewardService.processDailyRewardUpdate();
        
        if (result) {
            console.log("\n📋 Reward distribution summary:");
            console.log(`Epoch: ${result.epoch}`);
            console.log(`Merkle Root: ${result.merkleRoot}`);
            console.log(`Total Users: ${result.rewards.length}`);
            
            // Show some example user rewards
            result.rewards.slice(0, 3).forEach((reward, index) => {
                console.log(`User ${index + 1}: ${reward.user} - ${reward.totalReward} tokens`);
            });
        }

    } catch (error) {
        console.error("Failed to process reward update:", error);
    }
}

// Export for use in other modules
export {
    GraphQLRewardService,
    UserActivityData,
    Reward,
    RewardUpdate,
    UserRewardData
};

// Run if called directly
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
} 