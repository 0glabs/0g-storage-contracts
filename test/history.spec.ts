import { expect } from "chai";
import { ethers } from "hardhat";
import { DigestHistory } from "../typechain-types";
import { toBytes } from "./utils/bytes";

function testData(index: number): Uint8Array {
    const answer = Array(32).fill(0);
    answer[0] = index;
    answer[1] = 1;
    return Uint8Array.from(answer);
}

describe("Digest history", function () {
    let digestContract: DigestHistory;
    beforeEach(async () => {
        const digestABI = await ethers.getContractFactory("DigestHistory");
        digestContract = await digestABI.deploy(10);
    });

    it("insert without override", async () => {
        for (let i = 0; i < 8; i++) {
            await digestContract.insert(testData(i));
        }
        for (let i = 0; i < 8; i++) {
            expect(await digestContract.available(i)).true;
            expect(await digestContract.contains(testData(i))).true;
            expect(toBytes(await digestContract.at(i))).to.deep.equal(testData(i));
        }
        for (let i = 8; i < 10; i++) {
            expect(await digestContract.available(i)).false;
            await expect(digestContract.at(i)).to.be.revertedWithCustomError(digestContract, "UnavailableIndex");
        }
    });

    it("insert with override", async () => {
        for (let i = 0; i < 18; i++) {
            await digestContract.insert(testData(i));
        }
        for (let i = 8; i < 18; i++) {
            expect(await digestContract.available(i)).true;
            expect(await digestContract.contains(testData(i))).true;
            expect(toBytes(await digestContract.at(i))).to.deep.equal(testData(i));
        }
        for (let i = 0; i < 8; i++) {
            expect(await digestContract.contains(testData(i))).false;
            expect(await digestContract.available(i)).false;
            await expect(digestContract.at(i)).to.be.revertedWithCustomError(digestContract, "UnavailableIndex");
        }
    });
});
