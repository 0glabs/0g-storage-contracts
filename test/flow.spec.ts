import { expect } from "chai";
import hre, { deployments } from "hardhat";
import { CONTRACTS, getTypedContract } from "../src/utils/utils";
import { Flow } from "../typechain-types";

describe("ZeroGStorage Flow", function () {
    let flow: Flow;

    before(async () => {
        await deployments.fixture("no-market");

        flow = await getTypedContract(hre, CONTRACTS.Flow);
    });

    it("submit 256 sectors, in segment #0", async () => {
        const root = Buffer.from("ccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", "hex");
        const result = await flow.submit.staticCall({
            length: 256 * 256,
            tags: Buffer.from(""),
            nodes: [{ root, height: 8 }],
        });
        expect(result[0]).to.deep.eq(0n);
        expect(result[2]).to.deep.eq(256n);
        expect(result[3]).to.deep.eq(256n);
        await flow.submit({ length: 256 * 256, tags: Buffer.from(""), nodes: [{ root, height: 8 }] });
    });

    it("submit 960 sectors, pad to segment #1", async () => {
        const root = Buffer.from("ccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", "hex");
        const result = await flow.submit.staticCall({
            length: 960 * 256,
            tags: Buffer.from(""),
            nodes: [
                { root, height: 9 },
                { root, height: 8 },
                { root, height: 7 },
                { root, height: 6 },
            ],
        });
        expect(result[0]).to.deep.eq(1n);
        expect(result[2]).to.deep.eq(1024n);
        expect(result[3]).to.deep.eq(960n);
        await flow.submit({
            length: 960 * 256,
            tags: Buffer.from(""),
            nodes: [
                { root, height: 9 },
                { root, height: 8 },
                { root, height: 7 },
                { root, height: 6 },
            ],
        });
    });
    
    it("submit 960 sectors, pad to segment #2", async () => {
        const root = Buffer.from("ccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", "hex");
        const result = await flow.submit.staticCall({
            length: 960 * 256,
            tags: Buffer.from(""),
            nodes: [
                { root, height: 9 },
                { root, height: 8 },
                { root, height: 7 },
                { root, height: 6 },
            ],
        });
        expect(result[0]).to.deep.eq(2n);
        expect(result[2]).to.deep.eq(2048n);
        expect(result[3]).to.deep.eq(960n);
    });
});
