import { MockContract } from "@clrfund/waffle-mock-contract";
import { assert, expect } from "chai";
import { AbiCoder } from "ethers";
import { ethers, network } from "hardhat";
import { blake2b, keccak } from "hash-wasm";
import { IDataType } from "hash-wasm/dist/lib/util";

import { PoraMineTest } from "../typechain-types";

import { bufferToBigInt, hexToBuffer, numToU256 } from "./utils/converts";
import { deployMock } from "./utils/deploy";
import { genLeaves, MockMerkle } from "./utils/mockMerkleTree";
import {
    BHASHES_PER_PAD,
    BHASHES_PER_SEAL,
    SEALS_PER_PAD,
    SECTORS_PER_LOAD,
    SECTORS_PER_SEAL,
    UNITS_PER_SEAL,
} from "./utils/params";
import { Snapshot } from "./utils/snapshot";

async function keccak256(input: IDataType): Promise<Buffer> {
    return hexToBuffer(await keccak(input, 256));
}

const abiCoder = new AbiCoder();

type RecallRangeStruct = {
    startPosition: number;
    mineLength: number;
    shardId: bigint;
    shardMask: bigint;
};

type PoraAnswerStruct = {
    contextDigest: Buffer;
    nonce: Buffer;
    minerId: Buffer;
    range: RecallRangeStruct;
    recallPosition: number;
    sealOffset: number;
    sealedContextDigest: Buffer;
    sealedData: Buffer[];
    merkleProof: Buffer[];
};

type MineContextStruct = {
    epoch: number;
    mineStart: number;
    flowRoot: Buffer;
    flowLength: number;
    blockDigest: Buffer;
    digest: Buffer;
};

describe("Miner", function () {
    let mockFlow: MockContract;
    let mockReward: MockContract;
    let mineContract: PoraMineTest;
    let minerId: Buffer;
    let snapshot: Snapshot;

    before(async () => {
        const [owner] = await ethers.getSigners();

        mockFlow = await deployMock(owner, "Flow");
        mockReward = await deployMock(owner, "ChunkDecayReward");

        await mockReward.mock.claimMineReward.returns();

        const mineABI = await ethers.getContractFactory("PoraMineTest");
        mineContract = await mineABI.deploy(0);
        await mineContract.initialize(await mockFlow.getAddress(), await mockReward.getAddress(), {
            difficulty: 1,
            targetMineBlocks: 100,
            targetSubmissions: 10,
            maxShards: 32,
            nSubtasks: 1,
            subtaskInterval: 100,
        });
        await mineContract.setDifficultyAdjustRatio(1);

        minerId = await keccak256("minerId");
        await mineContract.setMiner(minerId);
        snapshot = await new Snapshot().snapshot();

        snapshot = await new Snapshot().snapshot();
    });

    beforeEach(async () => {
        await snapshot.revert();
    });

    async function makeTestData({
        length,
        flow,
        nonceSeed,
        shardMask,
        shardId,
        subtaskBlockDigest,
    }: {
        length?: number;
        flow?: MockMerkle;
        nonceSeed?: number;
        shardMask?: bigint;
        shardId?: bigint;
        subtaskBlockDigest?: Buffer;
    }) {
        const nonce = await keccak256(nonceSeed?.toString() || "nonce");

        const sealOffset = 11;

        const tree = flow || (await new MockMerkle(await genLeaves((length || 16384) - 1)).build());
        const range: RecallRangeStruct = {
            startPosition: 0,
            mineLength: tree.length(),
            shardMask: shardMask || BigInt(2) ** BigInt(64) - BigInt(1),
            shardId: shardId || BigInt(0),
        };

        const recallDigest = await keccak256(
            hexToBuffer(
                abiCoder.encode(
                    ["uint256", "uint256", "uint256", "uint256"],
                    [range.startPosition, range.mineLength, range.shardId, range.shardMask]
                )
            )
        );
        const context: MineContextStruct = await makeContextDigest(tree);
        const subtaskDigest: Buffer = await keccak256(
            Buffer.concat([context.digest, subtaskBlockDigest || context.blockDigest])
        );
        const { scratchPad, chunkOffset, padSeed } = await makeScratchPad(
            minerId,
            nonce,
            subtaskDigest,
            recallDigest,
            tree.length()
        );
        const realChunkOffset = (BigInt(chunkOffset) & range.shardMask) | range.shardId;
        const recallPosition = Number(realChunkOffset) * SECTORS_PER_LOAD + sealOffset * SECTORS_PER_SEAL;
        const unsealedData = await tree.getUnsealedData(recallPosition);

        const sealedContextDigest = await keccak256("44");
        const sealedData = await seal(minerId, sealedContextDigest, unsealedData, recallPosition);

        const answer: PoraAnswerStruct = {
            contextDigest: context.digest,
            nonce,
            minerId,
            range,
            recallPosition,
            sealOffset,
            sealedContextDigest,
            sealedData,
            merkleProof: tree.proof(recallPosition).slice(4),
        };

        const mixedData: Buffer[] = mixData(sealedData, scratchPad, sealOffset);

        const quality = (
            await blake2b(
                Buffer.concat([
                    numToU256(answer.sealOffset),
                    padSeed,
                    Buffer.from(Array(32).fill(0)),
                    Buffer.concat(mixedData),
                ])
            )
        ).slice(0, 64);

        return { context, answer, tree, scratchPad, unsealedData, quality, subtaskDigest };
    }

    it.skip("inspect gas cost (dev)", async () => {
        const { answer, unsealedData, context } = await makeTestData({});

        console.log("all: \t\t\t%d", await mineContract.testAll.estimateGas(answer, context.digest));

        console.log("unseal: \t\t%d", await mineContract.unseal.estimateGas(answer));

        console.log("recover merkle: \t%d", await mineContract.recoverMerkleRoot.estimateGas(answer, unsealedData));

        console.log("pora: \t\t\t%d", await mineContract.pora.estimateGas(answer, context.digest));
    });

    it("check valid submission", async () => {
        const { context, answer, tree, unsealedData, quality, subtaskDigest } = await makeTestData({});

        expect(await mineContract.unseal(answer)).to.deep.equal(unsealedData.map((x) => "0x" + x.toString("hex")));

        expect(hexToBuffer(await mineContract.recoverMerkleRoot(answer, unsealedData))).to.deep.equal(tree.root());

        expect(hexToBuffer(await mineContract.pora(answer, subtaskDigest))).to.deep.equal(
            hexToBuffer(quality.slice(0, 64))
        );

        await mockFlow.mock.getEpochRange
            .withArgs(answer.sealedContextDigest)
            .returns({ start: 0, end: tree.length() });

        await mockFlow.mock.makeContextWithResult.withArgs().returns(context);

        await mineContract.submit(answer);
    });

    it("sharded info test", async () => {
        const flow = await new MockMerkle(await genLeaves(16384 - 1)).build();
        for (let i = 0; i < 32; i++) {
            const { context, answer, tree, unsealedData, quality, subtaskDigest } = await makeTestData({
                shardMask: BigInt(2) ** BigInt(64) - BigInt(8),
                shardId: BigInt(3),
                nonceSeed: i,
                flow,
            });
            const q = hexToBuffer(quality.slice(0, 2))[0];
            if (q >= 0x80) {
                break;
            }

            expect(await mineContract.unseal(answer)).to.deep.equal(unsealedData.map((x) => "0x" + x.toString("hex")));

            expect(hexToBuffer(await mineContract.recoverMerkleRoot(answer, unsealedData))).to.deep.equal(tree.root());

            expect(hexToBuffer(await mineContract.pora(answer, subtaskDigest))).to.deep.equal(
                hexToBuffer(quality.slice(0, 64))
            );

            await mockFlow.mock.getEpochRange
                .withArgs(answer.sealedContextDigest)
                .returns({ start: 0, end: tree.length() });

            await mockFlow.mock.makeContextWithResult.withArgs().returns(context);

            if (q < 0x20) {
                await mineContract.submit(answer);
                await snapshot.revert();
            } else {
                await expect(mineContract.submit(answer)).to.be.revertedWith("Do not reach target quality");
            }
        }
    });

    it("incorrect sharded info test", async () => {
        const { context, answer } = await makeTestData({
            shardMask: BigInt(2) ** BigInt(64) - BigInt(2),
            shardId: BigInt(3),
        });

        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Masked bits should be zero");
    });

    it("out of bound sharded info test", async () => {
        const { answer, subtaskDigest } = await makeTestData({
            shardMask: BigInt(2) ** BigInt(64) - BigInt(8),
            shardId: BigInt(7),
            length: 1024 * 5,
        });
        await expect(mineContract.pora(answer, subtaskDigest)).to.be.revertedWith("Recall position out of bound");
    });

    it("check valid/invalid epoch range", async () => {
        const { context, answer } = await makeTestData({});

        await mockFlow.mock.makeContextWithResult.withArgs().returns(context);

        const localSnapshot = await new Snapshot().snapshot();

        await mockFlow.mock.getEpochRange.withArgs(answer.sealedContextDigest).returns({
            start: answer.recallPosition,
            end: answer.recallPosition + 16,
        });
        await mineContract.submit(answer);
        await localSnapshot.revert();

        await mockFlow.mock.getEpochRange.withArgs(answer.sealedContextDigest).returns({
            start: answer.recallPosition,
            end: answer.recallPosition + 15,
        });
        await expect(mineContract.submit(answer)).to.be.revertedWith("Invalid sealed context digest");
        await localSnapshot.revert();

        await mockFlow.mock.getEpochRange.withArgs(answer.sealedContextDigest).returns({
            start: answer.recallPosition + 1,
            end: answer.recallPosition + 16,
        });
        await expect(mineContract.submit(answer));
        await localSnapshot.revert();

        await mockFlow.mock.getEpochRange.withArgs(answer.sealedContextDigest).returns({
            start: answer.recallPosition + 15,
            end: answer.recallPosition + 16,
        });
        await expect(mineContract.submit(answer));
        await localSnapshot.revert();

        await mockFlow.mock.getEpochRange.withArgs(answer.sealedContextDigest).returns({
            start: answer.recallPosition + 16,
            end: answer.recallPosition + 17,
        });
        await expect(mineContract.submit(answer)).to.be.revertedWith("Invalid sealed context digest");
    });

    it("basic checks", async function () {
        const TB = (1024 * 1024 * 1024 * 1024) / 256;
        const GB = (1024 * 1024 * 1024) / 256;
        const KB = 1024 / 256;

        const { context, answer, tree } = await makeTestData({});
        context.flowLength = 10 * TB;
        await mockFlow.mock.makeContextWithResult.withArgs().returns(context);
        await mockFlow.mock.getEpochRange
            .withArgs(answer.sealedContextDigest)
            .returns({ start: 0, end: context.flowLength });

        answer.range.startPosition = 3 * TB;
        answer.range.mineLength = 8 * TB;
        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Mining range overflow");

        answer.range.startPosition = 2 * TB - GB;
        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Start position is not aligned");

        answer.range.startPosition = 2 * TB;
        answer.range.mineLength = 8 * TB - 8 * GB;
        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Mining range too short");

        answer.range.mineLength = 8 * TB;
        await mineContract.basicCheck(answer, context);

        answer.range.startPosition = 8 * GB;
        await mineContract.basicCheck(answer, context);

        context.flowLength = 8 * TB - 1;
        await mockFlow.mock.getEpochRange
            .withArgs(answer.sealedContextDigest)
            .returns({ start: 0, end: context.flowLength });

        answer.range.startPosition = 0;
        answer.range.mineLength = 8 * TB - 256 * KB;
        await mineContract.basicCheck(answer, context);

        answer.range.startPosition = 8 * GB;
        answer.range.mineLength = 8 * TB - 16 * GB;

        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Mining range too short");
    });
    it("Sharded mine range checks", async function () {
        const TB = (1024 * 1024 * 1024 * 1024) / 256;
        const GB = (1024 * 1024 * 1024) / 256;
        const KB = 1024 / 256;

        const { context, answer, tree } = await makeTestData({
            shardMask: BigInt(2) ** BigInt(64) - BigInt(2),
            shardId: BigInt(1),
        });
        context.flowLength = 20 * TB;
        await mockFlow.mock.makeContextWithResult.withArgs().returns(context);
        await mockFlow.mock.getEpochRange
            .withArgs(answer.sealedContextDigest)
            .returns({ start: 0, end: context.flowLength });

        answer.range.startPosition = 6 * TB;
        answer.range.mineLength = 16 * TB;
        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Mining range overflow");

        answer.range.startPosition = 4 * TB - GB;
        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Start position is not aligned");

        answer.range.startPosition = 4 * TB;
        answer.range.mineLength = 16 * TB - 8 * GB;
        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Mining range too short");

        answer.range.startPosition = 4 * TB;
        answer.range.mineLength = 16 * TB - 8 * GB;
        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Mining range too short");

        answer.range.mineLength = 16 * TB;
        await mineContract.basicCheck(answer, context);

        answer.range.startPosition = 16 * GB;
        await mineContract.basicCheck(answer, context);

        context.flowLength = 16 * TB - 1;
        await mockFlow.mock.getEpochRange
            .withArgs(answer.sealedContextDigest)
            .returns({ start: 0, end: context.flowLength });

        answer.range.startPosition = 0;
        answer.range.mineLength = 16 * TB - 256 * KB;
        await mineContract.basicCheck(answer, context);

        answer.range.startPosition = 8 * GB;
        answer.range.mineLength = 16 * TB - 16 * GB;

        await expect(mineContract.basicCheck(answer, context)).to.be.revertedWith("Mining range too short");
    });
});

async function seal(
    minerId: Buffer,
    contextDigest: Buffer,
    unsealedData: Buffer[],
    startPosition: number
): Promise<Buffer[]> {
    let maskInput = Buffer.concat([minerId, contextDigest, numToU256(startPosition)]);
    const sealedData = Array(128);
    for (let i = 0; i < 128; i++) {
        sealedData[i] = xor(unsealedData[i], await keccak256(maskInput));
        maskInput = sealedData[i];
    }
    return sealedData;
}

async function makeContextDigest(tree: MockMerkle, epoch?: number, mineStart?: number): Promise<MineContextStruct> {
    const KeccakEmpty: Buffer = hexToBuffer("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470");

    if (epoch === undefined) {
        epoch = 1;
    }

    if (mineStart === undefined) {
        mineStart = await ethers.provider.getBlockNumber();
    }

    const startBlock = (await ethers.provider.getBlock(mineStart))!;
    const blockDigest = hexToBuffer(startBlock.hash!);

    const context: MineContextStruct = {
        epoch,
        mineStart,
        flowRoot: tree.root(),
        flowLength: tree.length(),
        blockDigest,
        digest: KeccakEmpty,
    };

    const contextDigest = await keccak256(
        hexToBuffer(
            abiCoder.encode(
                ["bytes32", "bytes32", "uint256"],
                [context.blockDigest, context.flowRoot, context.flowLength]
            )
        )
    );
    context.digest = contextDigest;
    return context;
}

async function scratchPadItemHash(input: Buffer): Promise<Buffer> {
    return hexToBuffer(await blake2b(input));
}

async function scratchPadItemHashV2(input: Buffer): Promise<Buffer> {
    const firstHash = await keccak256(input);

    const secondInput = Buffer.concat([firstHash, input.subarray(32)]);

    const secondHash = await keccak256(secondInput);

    return Buffer.concat([firstHash, secondHash]);
}

async function makeScratchPad(
    minerId: Buffer,
    nonce: Buffer,
    subtaskDigest: Buffer,
    recallDigest: Buffer,
    length: number
): Promise<{ scratchPad: Buffer[]; chunkOffset: number; padSeed: Buffer }> {
    const answer = Array(BHASHES_PER_PAD);
    let input = hexToBuffer(await blake2b(Buffer.concat([minerId, nonce, subtaskDigest, recallDigest])));

    const padSeed = input;

    for (let i = 0; i < BHASHES_PER_PAD; i++) {
        answer[i] = await scratchPadItemHashV2(input);
        input = answer[i];
    }

    const chunks = Math.floor(length / SECTORS_PER_LOAD);

    const chunkOffset = Number(bufferToBigInt(await keccak256(answer[answer.length - 1])) % BigInt(chunks));
    const scratchPad = answer;

    return { scratchPad, chunkOffset, padSeed };
}

function mixData(sealedData: Buffer[], scratchPad: Buffer[], sealOffset: number): Buffer[] {
    return Array(UNITS_PER_SEAL)
        .fill(0)
        .map(function (_, i) {
            const scratchPadOffset = (sealOffset % SEALS_PER_PAD) * BHASHES_PER_SEAL;
            const padItem = scratchPad[scratchPadOffset + (i >> 1)];
            let mask;
            if (i % 2 === 0) {
                mask = padItem.subarray(0, 32);
            } else {
                mask = padItem.subarray(32, 64);
            }
            assert(sealedData[i] !== undefined);
            assert(mask !== undefined);
            return xor(sealedData[i], mask);
        });
}

function xor(x: Buffer, y: Buffer): Buffer {
    assert(x.length === y.length);
    const answer = [];
    for (let i = 0; i < x.length; i++) {
        answer.push(x[i] ^ y[i]);
    }
    return Buffer.from(answer);
}
