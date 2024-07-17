import { assert, expect } from "chai";
import { ethers } from "hardhat";
import { blake2b, keccak } from "hash-wasm";
import { deployMock } from "./utils/deploy";
import env = require("hardhat");

import { MockContract } from "@clrfund/waffle-mock-contract";
import { AbiCoder, keccak256 } from "ethers";
import { PoraMineTest } from "../typechain-types";
import { genLeaves, MockMerkle } from "./utils/mockMerkleTree";
import { Snapshot } from "./utils/snapshot";

const abiCoder = new AbiCoder();

function hexToBuffer(hex: string): Buffer {
    if (hex.slice(0, 2) === "0x") {
        hex = hex.slice(2);
    }
    return Buffer.from(hex, "hex");
}

function numToU256(num: number): Buffer {
    return hexToBuffer(abiCoder.encode(["uint256"], [num]));
}

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
    let mockCashier: MockContract;
    let mockReward: MockContract;
    let mineContract: PoraMineTest;
    let minerId: Buffer;
    let snapshot: Snapshot;

    before(async () => {
        const [owner] = await ethers.getSigners();

        mockFlow = await deployMock(owner, "Flow");
        mockCashier = await deployMock(owner, "Cashier");
        mockReward = await deployMock(owner, "ChunkDecayReward");

        await mockReward.mock.claimMineReward.returns();

        const mineABI = await ethers.getContractFactory("PoraMineTest");
        mineContract = await mineABI.deploy(0);
        await mineContract.initialize(1, await mockFlow.getAddress(), await mockReward.getAddress());
        await mineContract.setDifficultyAdjustRatio(1);

        minerId = hexToBuffer(await keccak("minerId", 256));
        await mineContract.setMiner(minerId);

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
    }: {
        length?: number;
        flow?: MockMerkle;
        nonceSeed?: number;
        shardMask?: bigint;
        shardId?: bigint;
    }) {
        const nonce = hexToBuffer(await keccak(nonceSeed?.toString() || "nonce", 256));

        const sealOffset = 11;

        const tree = flow || (await new MockMerkle(await genLeaves((length || 16384) - 1)).build());
        const range: RecallRangeStruct = {
            startPosition: 0,
            mineLength: tree.length(),
            shardMask: shardMask || BigInt(2) ** BigInt(64) - BigInt(1),
            shardId: shardId || BigInt(0),
        };

        const recallDigest = hexToBuffer(
            keccak256(
                abiCoder.encode(
                    ["uint256", "uint256", "uint256", "uint256"],
                    [range.startPosition, range.mineLength, range.shardId, range.shardMask]
                )
            )
        );
        const context: MineContextStruct = await makeContextDigest(tree);
        const { scratchPad, chunkOffset, padSeed } = await makeScratchPad(
            minerId,
            nonce,
            context.digest,
            recallDigest,
            tree.length()
        );
        const realChunkOffset = (BigInt(chunkOffset) & range.shardMask) | range.shardId;
        const recallPosition = Number(realChunkOffset) * 1024 + sealOffset * 16;
        const unsealedData = await tree.getUnsealedData(recallPosition);

        const sealedContextDigest = hexToBuffer(await keccak("44", 256));
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

        return { context, answer, tree, scratchPad, unsealedData, quality };
    }

    it("check valid submission", async () => {
        const { context, answer, tree, unsealedData, quality } = await makeTestData({});

        expect(await mineContract.unseal(answer)).to.deep.equal(unsealedData.map((x) => "0x" + x.toString("hex")));

        expect(hexToBuffer(await mineContract.recoverMerkleRoot(answer, unsealedData))).to.deep.equal(tree.root());

        expect(hexToBuffer(await mineContract.pora(answer))).to.deep.equal(hexToBuffer(quality.slice(0, 64)));

        await mockFlow.mock.getEpochRange
            .withArgs(answer.sealedContextDigest)
            .returns({ start: 0, end: tree.length() });

        await mockFlow.mock.makeContextWithResult.withArgs().returns(context);

        await mineContract.submit(answer);
    });

    it("sharded info test", async () => {
        const flow = await new MockMerkle(await genLeaves(16384 - 1)).build();
        for (let i = 0; i < 32; i++) {
            const { context, answer, tree, unsealedData, quality } = await makeTestData({
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

            expect(hexToBuffer(await mineContract.pora(answer))).to.deep.equal(hexToBuffer(quality.slice(0, 64)));

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
        const { answer } = await makeTestData({
            shardMask: BigInt(2) ** BigInt(64) - BigInt(8),
            shardId: BigInt(7),
            length: 1024 * 5,
        });
        await expect(mineContract.pora(answer)).to.be.revertedWith("Recall position out of bound");
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
        sealedData[i] = xor(unsealedData[i], hexToBuffer(await keccak(maskInput, 256)));
        maskInput = sealedData[i];
    }
    return sealedData;
}

async function makeContextDigest(
    tree: MockMerkle,
    epoch?: number,
    mineStart?: number,
    blockDigest?: Buffer
): Promise<MineContextStruct> {
    const KeccakEmpty: Buffer = hexToBuffer("c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470");

    if (blockDigest === undefined) {
        blockDigest = hexToBuffer(await keccak("blockDigest", 256));
    }

    if (epoch === undefined) {
        epoch = 1;
    }

    if (mineStart === undefined) {
        // not used now
        mineStart = 12;
    }

    const context: MineContextStruct = {
        epoch,
        mineStart,
        flowRoot: tree.root(),
        flowLength: tree.length(),
        blockDigest,
        digest: KeccakEmpty,
    };

    const contextDigest = hexToBuffer(
        await keccak(
            abiCoder.encode(
                ["bytes32", "bytes32", "uint256"],
                [context.blockDigest, context.flowRoot, context.flowLength]
            ),
            256
        )
    );
    context.digest = contextDigest;
    return context;
}

async function makeScratchPad(
    minerId: Buffer,
    nonce: Buffer,
    contextDigest: Buffer,
    recallDigest: Buffer,
    length: number
): Promise<{ scratchPad: Buffer[]; chunkOffset: number; padSeed: Buffer }> {
    const answer = Array(1024);

    let input = hexToBuffer(await blake2b(Buffer.concat([minerId, nonce, contextDigest, recallDigest])));

    const padSeed = input;

    for (let i = 0; i < 1024; i++) {
        answer[i] = hexToBuffer(await blake2b(input));
        input = answer[i];
    }

    const chunks = Math.floor(length / 1024);

    const chunkOffset = Number(BigInt("0x" + (await keccak(answer[answer.length - 1], 256))) % BigInt(chunks));
    const scratchPad = answer;

    return { scratchPad, chunkOffset, padSeed };
}

function mixData(sealedData: Buffer[], scratchPad: Buffer[], sealOffset: number): Buffer[] {
    return Array(128)
        .fill(0)
        .map(function (_, i) {
            const scratchPadOffset = (sealOffset % 16) * 64;
            let mask;
            if (i % 2 === 0) {
                mask = scratchPad[scratchPadOffset + (i >> 1)].slice(0, 32);
            } else {
                mask = scratchPad[scratchPadOffset + (i >> 1)].slice(32, 64);
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
