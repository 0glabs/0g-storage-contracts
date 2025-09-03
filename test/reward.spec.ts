import { expect } from "chai";
import { Signer } from "ethers";
import hre, { deployments, ethers } from "hardhat";
import { CONTRACTS, getTypedContract } from "../src/utils/utils";
import { ChunkLinearReward } from "../typechain-types";

describe("Chunk Reward Foundation Admin", function () {
    let chunkReward: ChunkLinearReward;
    let deployer: Signer;
    let foundationAdmin: Signer;
    let user: Signer;
    let newAdmin: Signer;
    let treasury: Signer;

    before(async function () {
        await deployments.fixture(["market-enabled"]);

        [deployer, foundationAdmin, user, newAdmin, treasury] = await ethers.getSigners();

        chunkReward = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);
    });

    describe("Foundation Admin Access Control", function () {
        it("should not allow non-foundation admin to call admin functions", async function () {
            const newFeeRate = 500; // 5%
            const treasuryAddress = await treasury.getAddress();
            const baseRewardAmount = ethers.parseEther("1.0");
            const newAdminAddress = await newAdmin.getAddress();

            // Test service fee rate
            await expect(chunkReward.connect(user).setServiceFeeRate(newFeeRate)).to.be.revertedWith(
                "Not foundation admin"
            );

            await expect(chunkReward.connect(deployer).setServiceFeeRate(newFeeRate)).to.be.revertedWith(
                "Not foundation admin"
            );

            // Test treasury address
            await expect(chunkReward.connect(user).setTreasury(treasuryAddress)).to.be.revertedWith(
                "Not foundation admin"
            );

            await expect(chunkReward.connect(deployer).setTreasury(treasuryAddress)).to.be.revertedWith(
                "Not foundation admin"
            );

            // Test base reward
            await expect(chunkReward.connect(user).setBaseReward(baseRewardAmount)).to.be.revertedWith(
                "Not foundation admin"
            );

            await expect(chunkReward.connect(deployer).setBaseReward(baseRewardAmount)).to.be.revertedWith(
                "Not foundation admin"
            );

            // Test foundation admin transfer
            await expect(chunkReward.connect(user).setFoundationAdmin(newAdminAddress)).to.be.revertedWith(
                "Not foundation admin"
            );

            await expect(chunkReward.connect(deployer).setFoundationAdmin(newAdminAddress)).to.be.revertedWith(
                "Not foundation admin"
            );
        });
    });

    describe("Foundation Admin Functions (with mock admin)", function () {
        let testChunkReward: ChunkLinearReward;

        beforeEach(async function () {
            // Deploy a fresh contract instance with our mock foundation admin
            const ChunkLinearRewardFactory = await ethers.getContractFactory("ChunkLinearReward");
            testChunkReward = await ChunkLinearRewardFactory.deploy(3 * 31 * 86400); // 3 months
            await testChunkReward.waitForDeployment();

            // Get market and mine addresses from the existing deployment
            const marketAddress = await chunkReward.market();
            const mineAddress = await chunkReward.mine();

            // Initialize with our mock foundation admin
            await testChunkReward.initialize(marketAddress, mineAddress, await foundationAdmin.getAddress());
        });

        it("should allow foundation admin to set all admin parameters", async function () {
            const newFeeRate = 750; // 7.5%
            const treasuryAddress = await treasury.getAddress();
            const baseRewardAmount = ethers.parseEther("2.0");

            // Test service fee rate
            await expect(testChunkReward.connect(foundationAdmin).setServiceFeeRate(newFeeRate)).to.not.be.reverted;
            expect(await testChunkReward.serviceFeeRateBps()).to.equal(newFeeRate);

            // Test treasury address
            await expect(testChunkReward.connect(foundationAdmin).setTreasury(treasuryAddress)).to.not.be.reverted;
            expect(await testChunkReward.treasury()).to.equal(treasuryAddress);

            // Test base reward
            await expect(testChunkReward.connect(foundationAdmin).setBaseReward(baseRewardAmount)).to.not.be.reverted;
            expect(await testChunkReward.baseReward()).to.equal(baseRewardAmount);
        });

        it("should allow foundation admin to transfer foundation admin role", async function () {
            const newAdminAddress = await newAdmin.getAddress();

            // Transfer foundation admin role
            await expect(testChunkReward.connect(foundationAdmin).setFoundationAdmin(newAdminAddress)).to.not.be
                .reverted;

            // Old admin should no longer have access
            await expect(testChunkReward.connect(foundationAdmin).setServiceFeeRate(400)).to.be.revertedWith(
                "Not foundation admin"
            );

            // New admin should have access
            await expect(testChunkReward.connect(newAdmin).setServiceFeeRate(400)).to.not.be.reverted;

            expect(await testChunkReward.serviceFeeRateBps()).to.equal(400);
        });
    });

    describe("Base Reward Functionality", function () {
        it("should allow anyone to donate to base reward pool", async function () {
            const donationAmount = ethers.parseEther("5.0");
            const initialBaseReward = await chunkReward.totalBaseReward();

            await expect(chunkReward.connect(user).donate({ value: donationAmount })).to.not.be.reverted;

            expect(await chunkReward.totalBaseReward()).to.equal(initialBaseReward + donationAmount);
        });

        it("should allow multiple donations to accumulate", async function () {
            const donation1 = ethers.parseEther("1.0");
            const donation2 = ethers.parseEther("2.0");
            const initialBaseReward = await chunkReward.totalBaseReward();

            await chunkReward.connect(user).donate({ value: donation1 });
            await chunkReward.connect(deployer).donate({ value: donation2 });

            expect(await chunkReward.totalBaseReward()).to.equal(initialBaseReward + donation1 + donation2);
        });
    });
});
