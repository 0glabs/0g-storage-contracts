import { expect } from "chai";
import { Signer } from "ethers";
import hre, { deployments, ethers } from "hardhat";
import { CONTRACTS, getTypedContract } from "../src/utils/utils";
import { ChunkLinearReward, FixedPrice, FixedPriceFlow } from "../typechain-types";

describe("FixedPriceFlow fee accounting", function () {
    let flow: FixedPriceFlow;
    let market: FixedPrice;
    let reward: ChunkLinearReward;
    let deployer: Signer;
    let user: Signer;
    let userAddress: string;
    let flowAddress: string;
    let marketAddress: string;
    let rewardAddress: string;
    let price: bigint;

    const ROOT = "0xccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";
    const SECTORS = 256n;

    function makeSubmission(submitter: string) {
        // one node of height 8 = 256 sectors
        return {
            data: { length: 256 * 256, tags: "0x", nodes: [{ root: ROOT, height: 8 }] },
            submitter,
        };
    }

    async function seedResidual(amount: bigint) {
        // simulate the balance stranded in the flow contract by historical overpayments
        await hre.network.provider.send("hardhat_setBalance", [flowAddress, ethers.toBeHex(amount)]);
    }

    beforeEach(async function () {
        await deployments.fixture(["market-enabled"]);

        [deployer, user] = await ethers.getSigners();
        userAddress = await user.getAddress();

        flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
        market = await getTypedContract(hre, CONTRACTS.FixedPrice);
        reward = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);

        flowAddress = await flow.getAddress();
        marketAddress = await market.getAddress();
        rewardAddress = await reward.getAddress();

        price = await market.pricePerSector();
    });

    it("accepts a submission paying the exact fee and forwards it to the reward pool", async function () {
        const fee = SECTORS * price;

        await expect(flow.connect(user).submit(makeSubmission(userAddress), { value: fee })).to.changeEtherBalances(
            [flowAddress, marketAddress, rewardAddress],
            [0n, 0n, fee]
        );
    });

    it("rejects a submission whose msg.value does not cover the fee even when the flow holds a residual balance", async function () {
        await seedResidual(ethers.parseEther("5"));

        await expect(
            flow.connect(user).submit(makeSubmission(userAddress), { value: 0 })
        ).to.be.revertedWithCustomError(flow, "NotEnoughFee");
    });

    it("refunds any payment above the fee", async function () {
        const fee = SECTORS * price;
        const excess = ethers.parseEther("1");

        await expect(
            flow.connect(user).submit(makeSubmission(userAddress), { value: fee + excess })
        ).to.changeEtherBalances([user, flowAddress, rewardAddress], [-fee, 0n, fee]);
    });

    it("requires msg.value to cover the total fee of a batch even when the flow holds a residual balance", async function () {
        await seedResidual(ethers.parseEther("5"));
        const fee = SECTORS * price;
        const submissions = [makeSubmission(userAddress), makeSubmission(userAddress)];

        // pays for only one of the two submissions
        await expect(flow.connect(user).batchSubmit(submissions, { value: fee })).to.be.revertedWithCustomError(
            flow,
            "NotEnoughFee"
        );
    });

    it("accepts a batch paying the exact total fee", async function () {
        const submissions = [makeSubmission(userAddress), makeSubmission(userAddress)];
        const totalFee = 2n * SECTORS * price;

        await expect(flow.connect(user).batchSubmit(submissions, { value: totalFee })).to.changeEtherBalances(
            [flowAddress, marketAddress, rewardAddress],
            [0n, 0n, totalFee]
        );
    });

    it("refunds any payment above the total fee of a batch", async function () {
        const submissions = [makeSubmission(userAddress), makeSubmission(userAddress)];
        const totalFee = 2n * SECTORS * price;
        const excess = ethers.parseEther("1");

        await expect(flow.connect(user).batchSubmit(submissions, { value: totalFee + excess })).to.changeEtherBalances(
            [user, flowAddress, rewardAddress],
            [-totalFee, 0n, totalFee]
        );
    });

    it("lets the admin sweep the residual balance to the market", async function () {
        const residual = ethers.parseEther("5");
        await seedResidual(residual);

        await expect(flow.connect(deployer).sweepResidualToMarket()).to.changeEtherBalances(
            [flowAddress, marketAddress],
            [-residual, residual]
        );
    });

    it("rejects a residual sweep from non-admin", async function () {
        await seedResidual(ethers.parseEther("5"));

        await expect(flow.connect(user).sweepResidualToMarket()).to.be.revertedWithCustomError(
            flow,
            "AccessControlUnauthorizedAccount"
        );
    });
});
