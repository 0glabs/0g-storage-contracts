import { expect } from "chai";
import hre, { deployments } from "hardhat";
import { CONTRACTS, getTypedContract } from "../src/utils/utils";
import { Flow } from "../typechain-types";

describe("ZeroGStorage Flow", function () {
    let flow: Flow;
    let submitter: string;

    before(async () => {
        await deployments.fixture("no-market");

        flow = await getTypedContract(hre, CONTRACTS.Flow);
        const { deployer } = await hre.getNamedAccounts();
        submitter = deployer;
    });

    it("submit 256 sectors, in segment #0", async () => {
        const root = "0xccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";
        const result = await flow.submit.staticCall({
            data: {
                length: 256 * 256,
                tags: "0x",
                nodes: [{ root, height: 8 }],
            },
            submitter,
        });
        expect(result[0]).to.deep.eq(0n);
        expect(result[2]).to.deep.eq(256n);
        expect(result[3]).to.deep.eq(256n);
        await flow.submit({
            data: { length: 256 * 256, tags: "0x", nodes: [{ root, height: 8 }] },
            submitter,
        });
    });

    it("submit 960 sectors, pad to segment #1", async () => {
        const root = "0xccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";
        const result = await flow.submit.staticCall({
            data: {
                length: 960 * 256,
                tags: "0x",
                nodes: [
                    { root, height: 9 },
                    { root, height: 8 },
                    { root, height: 7 },
                    { root, height: 6 },
                ],
            },
            submitter,
        });
        expect(result[0]).to.deep.eq(1n);
        expect(result[2]).to.deep.eq(1024n);
        expect(result[3]).to.deep.eq(960n);
        await flow.submit({
            data: {
                length: 960 * 256,
                tags: "0x",
                nodes: [
                    { root, height: 9 },
                    { root, height: 8 },
                    { root, height: 7 },
                    { root, height: 6 },
                ],
            },
            submitter,
        });
    });

    it("submit 960 sectors, pad to segment #2", async () => {
        const root = "0xccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";
        const result = await flow.submit.staticCall({
            data: {
                length: 960 * 256,
                tags: "0x",
                nodes: [
                    { root, height: 9 },
                    { root, height: 8 },
                    { root, height: 7 },
                    { root, height: 6 },
                ],
            },
            submitter,
        });
        expect(result[0]).to.deep.eq(2n);
        expect(result[2]).to.deep.eq(2048n);
        expect(result[3]).to.deep.eq(960n);
    });
});
