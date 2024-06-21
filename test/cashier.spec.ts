/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-unsafe-call */
import { MockContract } from "@clrfund/waffle-mock-contract";
import { assert, expect } from "chai";
import { parseEther, Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { CONTRACTS, deployDirectly, getTypedContract } from "../src/utils/utils";
import { CashierTest, ChunkDecayReward } from "../typechain-types";
import { deployMock } from "./utils/deploy";
import { increaseTime, Snapshot } from "./utils/snapshot";

const KB: number = 1024;
const MB: number = 1024 * KB;
const GB: number = 1024 * MB;
const TB: number = 1024 * GB;
const BYTES_PER_SECTOR = 256;
const BASIC_PRICE = 1000;
const UPLOAD_TOKEN_PER_SECTOR: bigint = BigInt(10) ** BigInt(18);

describe("Cashier", function () {
    let mockUploadToken: MockContract;
    let mockZgsToken: MockContract;

    let cashier_: CashierTest;
    let reward_: ChunkDecayReward;
    let snapshot: Snapshot;
    let owner: Signer;
    let mockMine: Signer;
    let mockFlow: Signer;
    let mockStake: Signer;

    before(async () => {
        [owner, mockMine, mockFlow, mockStake] = await ethers.getSigners();

        mockUploadToken = await deployMock(owner, "UploadToken");
        mockZgsToken = await deployMock(owner, "MockHackToken");

        await mockZgsToken.mock.receiveNative.returns();
        await mockZgsToken.receiveNative({ value: parseEther("1000") });

        await deployDirectly(hre, CONTRACTS.ChunkDecayReward, [40]);
        await deployDirectly(hre, CONTRACTS.CashierTest, [await mockZgsToken.getAddress()]);
        reward_ = await getTypedContract(hre, CONTRACTS.ChunkDecayReward);
        cashier_ = await getTypedContract(hre, CONTRACTS.CashierTest);

        await (await reward_.initialize(await cashier_.getAddress(), await mockMine.getAddress())).wait();

        await (
            await cashier_.initialize(
                await mockFlow.getAddress(),
                await mockMine.getAddress(),
                await reward_.getAddress(),
                await mockUploadToken.getAddress(),
                await mockStake.getAddress(),
                { value: parseEther("1000") }
            )
        ).wait();

        snapshot = await new Snapshot().snapshot();
    });

    beforeEach(async () => {
        await snapshot.revert();
    });

    describe("Test Gauge Drip", () => {
        it("Normal case", async () => {
            await cashier_.updateTotalSubmission((3 * TB) / BYTES_PER_SECTOR);
            const beforeGauge = await cashier_.gauge();
            await increaseTime(100);
            await cashier_.refreshGauge();
            const afterGauge = await cashier_.gauge();
            assert(afterGauge - beforeGauge === BigInt(300 * MB), "Incorrect gauge delta");
        });

        it("Upper bound capped", async () => {
            await cashier_.updateTotalSubmission((3 * TB) / BYTES_PER_SECTOR);
            await increaseTime(20000);
            await cashier_.refreshGauge();
            const afterGauge = await cashier_.gauge();
            assert(afterGauge === BigInt(30 * GB));
        });

        it("Small dripping rate", async () => {
            await cashier_.updateTotalSubmission((1 * TB) / BYTES_PER_SECTOR - 1);
            const beforeGauge = await cashier_.gauge();
            await increaseTime(100);
            await cashier_.refreshGauge();
            const afterGauge = await cashier_.gauge();
            assert(afterGauge - beforeGauge === BigInt(100 * MB), "Incorrect gauge delta");
        });

        it("Dynamic dripping rate", async () => {
            await cashier_.updateTotalSubmission((1 * TB) / BYTES_PER_SECTOR - 1);
            const beforeGauge = await cashier_.gauge();
            await increaseTime(100);
            await cashier_.updateTotalSubmission((1 * TB) / BYTES_PER_SECTOR);
            await increaseTime(100);
            await cashier_.refreshGauge();
            const afterGauge = await cashier_.gauge();
            assert(afterGauge - beforeGauge === BigInt(300 * MB), "Incorrect gauge delta");
        });

        it("Dripping with purchase", async () => {
            await mockZgsToken.mock.transferFrom.returns(true);

            await cashier_.updateTotalSubmission((3 * TB) / BYTES_PER_SECTOR - 1);
            const beforeGauge = await cashier_.gauge();
            await increaseTime(100);
            await cashier_.purchase((50 * MB) / BYTES_PER_SECTOR, BASIC_PRICE, 0);
            await increaseTime(100);
            await cashier_.refreshGauge();
            const afterGauge = await cashier_.gauge();
            assert(afterGauge - beforeGauge === BigInt(550 * MB), "Incorrect gauge delta");
        });
    });

    describe("Test Priority Fee", () => {
        function assertApproximate(expected: bigint, actual: bigint) {
            const error = expected > actual ? expected - actual : actual - expected;
            const maxError = actual / BigInt(2 ** 32) + BigInt(1);
            assert(error <= maxError);
        }
        const BASE = 900 * MB;
        const MIN_PRICE = BASIC_PRICE / 100;
        const F = (x: number) => 2 ** ((x * GB) / BASE) * BASE * MIN_PRICE;
        const int_f = function (start: number, delta: number) {
            const x = (delta * Math.log(2)) / BASE;
            const k = 2 ** ((start * GB) / BASE);
            return k * (x + x ** 2 / 2 + x ** 3 / 6 + x ** 4 / 24 + x ** 5 / 120) * BASE * MIN_PRICE;
        };

        it("Free", async () => {
            await cashier_.setGauge(30 * GB);
            const fee = await cashier_.computePriorityFee(20 * GB);
            assert(fee === BigInt(0), "Incorrect priority fee");
        });

        it("Charged", async () => {
            await cashier_.setGauge(-10 * GB);
            const fee = await cashier_.computePriorityFee(1 * GB);
            const expectedFee = F(11) - F(10);

            assertApproximate(BigInt(Math.floor(expectedFee)), fee);
        });

        it("Partial paid", async () => {
            await cashier_.setGauge(30 * GB);
            const fee = await cashier_.computePriorityFee(40 * GB);
            const expectedFee = F(10) - F(0);

            assertApproximate(BigInt(Math.floor(expectedFee)), fee);
        });

        it("Large purchase", async () => {
            await cashier_.setGauge(0);
            const fee = await cashier_.computePriorityFee(100 * GB);
            const expectedFee = F(100) - F(0);

            assertApproximate(BigInt(Math.floor(expectedFee)), fee);
        });

        it("Large price and small purchase", async () => {
            await cashier_.setGauge(-99 * GB);
            const fee = await cashier_.computePriorityFee(256);
            const expectedFee = int_f(99, 256);

            assertApproximate(BigInt(Math.floor(expectedFee)), fee);
        });

        it("Gauge underflow", async () => {
            await cashier_.setGauge(-100 * GB);
            await expect(cashier_.computePriorityFee(256)).to.be.revertedWith("Gauge underflow");
        });
    });

    describe("Test Purchase", () => {
        it("No priority and tip", async () => {
            await cashier_.setGauge(20 * GB);
            await mockZgsToken.mock.transferFrom.revertsWithReason("Unexpected args");
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await cashier_.getAddress(), BASIC_PRICE * 10 * BYTES_PER_SECTOR)
                .returns(true);

            await cashier_.purchase(10, BASIC_PRICE, 0);
            expect(await cashier_.paidUploadAmount()).equal(10);
            expect(await cashier_.paidFee()).equal(BASIC_PRICE * 10 * BYTES_PER_SECTOR);
            expect(await cashier_.gauge()).equal(20 * GB - 10 * BYTES_PER_SECTOR);
        });

        it("Not paid", async () => {
            await cashier_.setGauge(20 * GB);
            await mockZgsToken.mock.transferFrom.revertsWithReason("Unexpected args");
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await cashier_.getAddress(), BASIC_PRICE * 10 * BYTES_PER_SECTOR)
                .revertsWithReason("Not allowed");

            await expect(cashier_.purchase(10, BASIC_PRICE, 0)).to.be.revertedWith("Not allowed");
        });

        it("Only tip", async () => {
            await cashier_.setGauge(20 * GB);
            await mockZgsToken.mock.transferFrom.revertsWithReason("Unexpected args");
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await cashier_.getAddress(), BASIC_PRICE * 20 * BYTES_PER_SECTOR)
                .returns(true);

            await cashier_.purchase(10, BASIC_PRICE * 2, BASIC_PRICE);
            expect(await cashier_.paidUploadAmount()).equal(10);
            expect(await cashier_.paidFee()).equal(BASIC_PRICE * 20 * BYTES_PER_SECTOR);
            expect(await cashier_.gauge()).equal(20 * GB - 10 * BYTES_PER_SECTOR);
        });

        it("Capped tip", async () => {
            await cashier_.setGauge(20 * GB);
            await mockZgsToken.mock.transferFrom.revertsWithReason("Unexpected args");
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await cashier_.getAddress(), BASIC_PRICE * 20 * BYTES_PER_SECTOR)
                .returns(true);

            await cashier_.purchase(10, BASIC_PRICE * 2, BASIC_PRICE * 1.5);
            expect(await cashier_.paidUploadAmount()).equal(10);
            expect(await cashier_.paidFee()).equal(BASIC_PRICE * 20 * BYTES_PER_SECTOR);
            expect(await cashier_.gauge()).equal(20 * GB - 10 * BYTES_PER_SECTOR);
        });

        it("Only priority", async () => {
            await cashier_.setGauge(-20 * GB);
            const priorFee = await cashier_.computePriorityFee(10 * BYTES_PER_SECTOR);
            const priorPrice = priorFee / BigInt(10 * BYTES_PER_SECTOR) + BigInt(1);

            await mockZgsToken.mock.transferFrom.revertsWithReason("Unexpected args");
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await cashier_.getAddress(), BASIC_PRICE * 10 * BYTES_PER_SECTOR)
                .returns(true);
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await mockStake.getAddress(), priorFee)
                .returns(true);

            await cashier_.purchase(10, BigInt(BASIC_PRICE) + priorPrice, 0);
            expect(await cashier_.paidUploadAmount()).equal(10);
            expect(await cashier_.paidFee()).equal(BASIC_PRICE * 10 * BYTES_PER_SECTOR);
            expect(await cashier_.gauge()).equal(-20 * GB - 10 * BYTES_PER_SECTOR);
        });

        it("Not enough max fee", async () => {
            await cashier_.setGauge(-20 * GB);
            const priorFee = await cashier_.computePriorityFee(10 * BYTES_PER_SECTOR);
            const priorPrice = priorFee / BigInt(10 * BYTES_PER_SECTOR) + BigInt(1);

            await expect(cashier_.purchase(10, priorPrice, 0)).to.be.revertedWith("Exceed price limit");
        });

        it("Priority and tip", async () => {
            await cashier_.setGauge(-20 * GB);
            const priorFee = await cashier_.computePriorityFee(10 * BYTES_PER_SECTOR);
            const priorPrice = priorFee / BigInt(10 * BYTES_PER_SECTOR) + BigInt(1);

            await mockZgsToken.mock.transferFrom.revertsWithReason("Unexpected args");
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await cashier_.getAddress(), BASIC_PRICE * 20 * BYTES_PER_SECTOR)
                .returns(true);
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await mockStake.getAddress(), priorFee)
                .returns(true);

            await cashier_.purchase(10, BigInt(2) * BigInt(BASIC_PRICE) + priorPrice, BASIC_PRICE);
            expect(await cashier_.paidUploadAmount()).equal(10);
            expect(await cashier_.paidFee()).equal(BASIC_PRICE * 20 * BYTES_PER_SECTOR);
            expect(await cashier_.gauge()).equal(-20 * GB - 10 * BYTES_PER_SECTOR);
        });

        it("Priority and capped tip", async () => {
            await cashier_.setGauge(-20 * GB);
            const priorFee = await cashier_.computePriorityFee(10 * BYTES_PER_SECTOR);
            const priorPrice = priorFee / BigInt(10 * BYTES_PER_SECTOR) + BigInt(1);

            await mockZgsToken.mock.transferFrom.revertsWithReason("Unexpected args");
            await mockZgsToken.mock.transferFrom
                .withArgs(
                    await owner.getAddress(),
                    await cashier_.getAddress(),
                    (BigInt(BASIC_PRICE) + priorPrice) * BigInt(10 * BYTES_PER_SECTOR) - priorFee
                )
                .returns(true);
            await mockZgsToken.mock.transferFrom
                .withArgs(await owner.getAddress(), await mockStake.getAddress(), priorFee)
                .returns(true);

            await cashier_.purchase(10, BigInt(BASIC_PRICE) + priorPrice, BigInt(BASIC_PRICE));
            expect(await cashier_.paidUploadAmount()).equal(10);
            expect(await cashier_.paidFee()).equal(
                (BigInt(BASIC_PRICE) + priorPrice) * BigInt(10 * BYTES_PER_SECTOR) - priorFee
            );
            expect(await cashier_.gauge()).equal(-20 * GB - 10 * BYTES_PER_SECTOR);
        });
    });

    describe("Test Consume Upload Token", () => {
        it("Success case", async () => {
            await cashier_.setGauge(-20 * GB);

            // await mockUploadToken.mock.consume.revertsWithReason("Unexpected args");
            await mockUploadToken.mock.consume
                .withArgs(await owner.getAddress(), BigInt(10) * UPLOAD_TOKEN_PER_SECTOR)
                .returns();
            await cashier_.consumeUploadToken(10);

            expect(await cashier_.paidUploadAmount()).equal(10);
            expect(await cashier_.paidFee()).equal(BASIC_PRICE * 10 * BYTES_PER_SECTOR);
            expect(await cashier_.gauge()).equal(-20 * GB);
        });

        it("Fail case", async () => {
            await cashier_.setGauge(-20 * GB);

            // await mockUploadToken.mock.consume.revertsWithReason("Unexpected args");
            await mockUploadToken.mock.consume
                .withArgs(await owner.getAddress(), BigInt(10) * UPLOAD_TOKEN_PER_SECTOR)
                .revertsWithReason("Cannot consume");
            await expect(cashier_.consumeUploadToken(10)).to.revertedWith("Cannot consume");
        });
    });

    describe("Test Charge Fee for Mine", () => {
        async function topup(sectors: number) {
            await mockUploadToken.mock.consume.returns();
            await cashier_.consumeUploadToken(sectors);
        }
        let cashierInternal: CashierTest;
        before(async () => {
            cashierInternal = await cashier_.connect(mockFlow);
        });

        it("Permission test", async () => {
            await expect(cashier_.chargeFeeTest(7, 8)).to.be.revertedWith("Sender does not have permission");
        });

        it("Update dripping rate", async () => {
            await mockUploadToken.mock.consume.returns();
            const SECTORS = 1024 * 1024;
            await topup(SECTORS);
            await cashierInternal.chargeFeeTest(SECTORS, SECTORS - 1);
            expect(await cashier_.drippingRate()).to.equal((2 * SECTORS * BYTES_PER_SECTOR) / MB);
        });

        it("Not paid", async () => {
            await topup(4);
            await expect(cashierInternal.chargeFeeTest(8, 7)).to.be.revertedWith("Data submission is not paid");
        });

        it("Charge partial", async () => {
            await topup(16);
            await cashierInternal.chargeFeeTest(8, 7);
            expect(await cashier_.paidFee()).equal(8 * BYTES_PER_SECTOR * BASIC_PRICE);
            expect(await cashier_.paidUploadAmount()).equal(8);
        });

        it("Charge in one pricing chunk", async () => {
            await cashier_.updateTotalSubmission((2 * GB) / BYTES_PER_SECTOR - 1);
            await topup((8 * GB) / BYTES_PER_SECTOR);
            {
                await cashierInternal.chargeFeeTest((2 * GB) / BYTES_PER_SECTOR, 0);
                const reward = await reward_.rewards(0);
                assert(reward.claimableReward === 0n);
                assert(reward.lockedReward === BigInt(2 * GB) * BigInt(BASIC_PRICE));
                assert(reward.startTime === 0n);

                const rewardNext = await reward_.rewards(1);
                assert(rewardNext.lockedReward === 0n);
            }

            {
                await cashierInternal.chargeFeeTest((4 * GB) / BYTES_PER_SECTOR, 0);
                const reward = await reward_.rewards(0);
                assert(reward.claimableReward === 0n);
                assert(reward.lockedReward === BigInt(6 * GB) * BigInt(BASIC_PRICE));
                assert(reward.startTime > 0);

                const rewardNext = await reward_.rewards(1);
                assert(rewardNext.lockedReward === 0n);
            }

            {
                await cashierInternal.chargeFeeTest((2 * GB) / BYTES_PER_SECTOR, 0);
                const reward = await reward_.rewards(1);
                assert(reward.claimableReward === 0n);
                assert(reward.lockedReward === BigInt(2 * GB) * BigInt(BASIC_PRICE));
                assert(reward.startTime === 0n);

                const rewardNext = await reward_.rewards(2);
                assert(rewardNext.lockedReward === 0n);
            }
        });

        it("Charge across three pricing chunk", async () => {
            await cashier_.updateTotalSubmission((2 * GB) / BYTES_PER_SECTOR - 1);
            await topup((16 * GB) / BYTES_PER_SECTOR);
            {
                await cashierInternal.chargeFeeTest((16 * GB) / BYTES_PER_SECTOR, 0);
                const reward0 = await reward_.rewards(0);
                assert(reward0.claimableReward === 0n);
                assert(reward0.lockedReward === BigInt(6 * GB) * BigInt(BASIC_PRICE));
                assert(reward0.startTime > 0);

                const reward1 = await reward_.rewards(1);
                assert(reward1.claimableReward === 0n);
                assert(reward1.lockedReward === BigInt(8 * GB) * BigInt(BASIC_PRICE));
                assert(reward1.startTime > 0);

                const reward2 = await reward_.rewards(2);
                assert(reward2.claimableReward === 0n);
                assert(reward2.lockedReward === BigInt(2 * GB) * BigInt(BASIC_PRICE));
                assert(reward2.startTime === 0n);

                const rewardNext = await reward_.rewards(3);
                assert(rewardNext.lockedReward === 0n);
            }
        });

        describe("Test Claim Reward for Mine", () => {
            async function imposeReward(finalized: boolean) {
                await cashier_.updateTotalSubmission((2 * GB) / BYTES_PER_SECTOR - 1);
                await mockUploadToken.mock.consume.returns();
                await cashier_.consumeUploadToken((6 * GB) / BYTES_PER_SECTOR);
                if (finalized) {
                    await cashier_.connect(mockFlow).chargeFeeTest((6 * GB) / BYTES_PER_SECTOR, 0);
                } else {
                    await cashier_.connect(mockFlow).chargeFeeTest((5 * GB) / BYTES_PER_SECTOR, 0);
                }
            }
            let cashierInternal: CashierTest;
            before(async () => {
                cashierInternal = await cashier_.connect(mockMine);
            });

            it("Permission test", async () => {
                const minerId = Buffer.from("0000000000000000000000000000000000000000000000000000000000000001", "hex");
                await expect(reward_.claimMineReward(0, await owner.getAddress(), minerId)).to.be.revertedWith(
                    "Sender does not have permission"
                );
            });
        });
    });
});
