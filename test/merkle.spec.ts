import { expect } from "chai";
import { Contract } from "ethers";
import { ethers } from "hardhat";
import { MerkleTreeTest } from "../typechain-types";
import { genLeaf, genLeaves, MockMerkle } from "./utils/mockMerkleTree";

function toBuffer(input: string): Buffer {
    return Buffer.from(input.slice(2), "hex");
}

describe("Incremental merkle hash", function () {
    let merkle: MerkleTreeTest;

    beforeEach(async () => {
        const merkleABI = await ethers.getContractFactory("MerkleTreeTest");
        merkle = await merkleABI.deploy();
    });

    it("init root", async () => {
        const ZEROS = Buffer.from(Array(32).fill(0));
        const response = toBuffer(await merkle.root());
        expect(response).to.deep.equal(ZEROS);
    });

    it("one element", async () => {
        const allLeaves = await genLeaves(1);
        const tree = await new MockMerkle(allLeaves).build();

        await merkle.insertNode(await genLeaf(1), 0);
        await merkle.commitRoot();

        expect(await merkle.currentLength()).to.equal(2);
        expect(await merkle.unstagedHeight()).to.equal(2);
        const response = toBuffer(await merkle.root());
        expect(response).to.deep.equal(tree.root());
    });

    it("padding element", async () => {
        const allLeaves: Buffer[] = await genLeaves(3);
        allLeaves[0] = await genLeaf(0);
        const tree = await new MockMerkle(allLeaves).build();

        await merkle.insertNode(tree.at("1"), 1);
        await merkle.commitRoot();

        expect(await merkle.currentLength()).to.equal(4);
        expect(await merkle.unstagedHeight()).to.equal(3);

        const response = toBuffer(await merkle.root());
        expect(response).to.deep.equal(tree.root());
    });

    it("multiple insert with active commit", async () => {
        const allLeaves: Buffer[] = await genLeaves(7);
        allLeaves[0] = await genLeaf(0);

        const tree = await new MockMerkle(allLeaves).build();

        await merkle.insertNode(tree.at("01"), 1);
        await merkle.commitRoot();
        await merkle.insertNode(tree.at("10"), 1);
        await merkle.commitRoot();
        await merkle.insertNode(tree.at("110"), 0);
        await merkle.commitRoot();
        await merkle.insertNode(tree.at("111"), 0);
        await merkle.commitRoot();

        expect(await merkle.currentLength()).to.equal(8);
        expect(await merkle.unstagedHeight()).to.equal(4);

        const response = toBuffer(await merkle.root());
        expect(response).to.deep.equal(tree.root());
    });

    it("multiple insert with lazy commit", async () => {
        const allLeaves: Buffer[] = await genLeaves(7);
        allLeaves[0] = await genLeaf(0);

        const tree = await new MockMerkle(allLeaves).build();

        await merkle.insertNode(tree.at("01"), 1);
        await merkle.insertNode(tree.at("10"), 1);
        await merkle.insertNode(tree.at("110"), 0);
        await merkle.insertNode(tree.at("111"), 0);
        await merkle.commitRoot();

        expect(await merkle.currentLength()).to.equal(8);
        expect(await merkle.unstagedHeight()).to.equal(4);

        const response = toBuffer(await merkle.root());
        expect(response).to.deep.equal(tree.root());
    });

    it("multiple insert with lazy commit and padding", async () => {
        const allLeaves: Buffer[] = await genLeaves(12);
        for (let i = 0; i < 3; i++) {
            allLeaves[i] = await genLeaf(0);
        }

        allLeaves[8] = await genLeaf(0);

        const tree = await new MockMerkle(allLeaves).build();

        await merkle.insertNode(tree.at("01"), 2);
        await merkle.insertNode(tree.at("1000"), 0);
        await merkle.insertNode(tree.at("101"), 1);
        await merkle.insertNode(tree.at("1100"), 0);
        expect(await merkle.unstagedHeight()).to.equal(1);
        await merkle.commitRoot();

        expect(await merkle.currentLength()).to.equal(13);
        expect(await merkle.unstagedHeight()).to.equal(5);

        const response = toBuffer(await merkle.root());
        expect(response).to.deep.equal(tree.root());
    });

    it("merkle root consistency with random workload", async () => {
        const iterations = 5;
        const submissions = 25;
        const range = 12;
        for (let i = 0; i < iterations; i++) {
            const task = Array(submissions)
                .fill(0)
                .map(() => {
                    return Math.floor(Math.random() * range);
                });
            await testFromHeight(task);
        }
    });

    it.skip("merkle root consistency with random workload (slow)", async () => {
        const iterations = 100;
        const submissions = 25;
        const range = 12;
        const tasks = [];
        for (let i = 0; i < iterations; i++) {
            const task = Array(submissions)
                .fill(0)
                .map(() => {
                    return Math.floor(Math.random() * range);
                });
            tasks.push(task);
        }
        await Promise.all(tasks.map((x) => testFromHeight(x)));
    });
});

async function buildLeafFromHeight(heights: number[]): Promise<MockMerkle> {
    const EMPTY_LEAF = await genLeaf(0);
    const leaves = [];
    while (heights.length > 0) {
        const height = heights[0];
        if ((leaves.length + 1) % (1 << height) != 0) {
            leaves.push(EMPTY_LEAF);
        } else {
            for (let i = 0; i < 1 << height; i++) {
                leaves.push(await genLeaf(leaves.length + 1));
            }
            heights = heights.slice(1);
        }
    }
    return await new MockMerkle(leaves).build();
}

async function insertNodeFromHeight(merkle: Contract, heights: number[], tree: MockMerkle) {
    const totalHeight = tree.height();
    let nextIndex = 1;

    const indexToPath = function (index: number, height: number) {
        let answer: string = "";
        while (index > 0) {
            answer = (index % 2).toString() + answer;
            index = Math.floor(index / 2);
        }
        while (answer.length < totalHeight - 1) {
            answer = "0" + answer;
        }
        answer = answer.slice(0, answer.length - height);
        return answer;
    };

    for (const height of heights) {
        nextIndex = Math.ceil(nextIndex / (1 << height)) * (1 << height);
        await merkle.insertNode(tree.at(indexToPath(nextIndex, height)), height);
        nextIndex += 1 << height;
    }
}

async function testFromHeight(heights: number[]) {
    const merkleABI = await ethers.getContractFactory("MerkleTreeTest");
    const merkle = await merkleABI.deploy();
    const tree = await buildLeafFromHeight(heights);
    await insertNodeFromHeight(merkle, heights, tree);
    await merkle.commitRoot();

    const response = toBuffer(await merkle.root());
    expect(response).to.deep.equal(tree.root());
}
