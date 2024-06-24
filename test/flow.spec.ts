import { Signer } from "ethers";
import hre, { deployments, ethers } from "hardhat";
import { CONTRACTS, getTypedContract } from "../src/utils/utils";
import { Flow } from "../typechain-types";

describe("ZeroGStorage Flow", function () {
    let flow: Flow;

    before(async () => {
        await deployments.fixture("no-market");

        flow = await getTypedContract(hre, CONTRACTS.Flow);
    });

    it("submit", async () => {
        const root = Buffer.from("ccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", "hex");
        await flow.submit({ length: 256 * 256, tags: Buffer.from(""), nodes: [{ root, height: 8 }] });
    });
});
