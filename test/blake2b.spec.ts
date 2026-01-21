import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { blake2b } from "hash-wasm";
import { Blake2bTest } from "../typechain-types";

function hexToBytes(hex: string): Uint8Array {
    return Uint8Array.from(Buffer.from(hex.substring(2), "hex"));
}

function concatBytes(parts: readonly Uint8Array[]): Uint8Array {
    const total = parts.reduce((sum, part) => sum + part.length, 0);
    const out = new Uint8Array(total);
    let offset = 0;
    for (const part of parts) {
        out.set(part, offset);
        offset += part.length;
    }
    return out;
}

function bufferResponse(response: string[]) {
    return concatBytes(response.map(hexToBytes));
}

function bufferAnswer(answer: string) {
    return Uint8Array.from(Buffer.from(answer, "hex"));
}

describe("Blake2b hash", function () {
    let blake2bContract: Blake2bTest;
    before(async () => {
        await deployments.fixture("blake2b-test");
        const blakeABI = await ethers.getContractFactory("Blake2bTest");
        blake2bContract = await blakeABI.deploy();
    });

    it("hash empty", async () => {
        const input = Uint8Array.from([]);
        const answer = bufferAnswer(await blake2b(input));
        const response = bufferResponse(await blake2bContract.blake2b([]));
        expect(response).to.deep.equal(answer);
    });

    it("hash one entry", async () => {
        const input = Uint8Array.from(
            Buffer.from("000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f", "hex")
        );
        const answer = bufferAnswer(await blake2b(input));
        const response = bufferResponse(await blake2bContract.blake2b([input]));
        expect(response).to.deep.equal(answer);
    });

    it("hash two entries", async () => {
        const input0 = Uint8Array.from(
            Buffer.from("000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f", "hex")
        );
        const input1 = Uint8Array.from(
            Buffer.from("101112131415161718191a1b1c1d1e1f101112131415161718191a1b1c1d1e1f", "hex")
        );
        const answer = bufferAnswer(await blake2b(concatBytes([input0, input1])));
        const response = bufferResponse(await blake2bContract.blake2b([input0, input1]));
        expect(response).to.deep.equal(answer);

        const response2 = bufferResponse(await blake2bContract.blake2bPair([input0, input1]));
        expect(response2).to.deep.equal(answer);
    });

    it("hash three entries", async () => {
        const input0 = Uint8Array.from(
            Buffer.from("000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f", "hex")
        );
        const input1 = Uint8Array.from(
            Buffer.from("101112131415161718191a1b1c1d1e1f101112131415161718191a1b1c1d1e1f", "hex")
        );
        const input2 = Uint8Array.from(
            Buffer.from("202122232425262728292a2b2c2d2e2f202122232425262728292a2b2c2d2e2f", "hex")
        );
        const answer = bufferAnswer(await blake2b(concatBytes([input0, input1, input2])));
        const response = bufferResponse(await blake2bContract.blake2b([input0, input1, input2]));
        expect(response).to.deep.equal(answer);

        const response2 = bufferResponse(await blake2bContract.blake2bTriple([input0, input1, input2]));
        expect(response2).to.deep.equal(answer);
    });

    it("hash five entries", async () => {
        const input0 = Uint8Array.from(
            Buffer.from("000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f", "hex")
        );
        const input1 = Uint8Array.from(
            Buffer.from("101112131415161718191a1b1c1d1e1f101112131415161718191a1b1c1d1e1f", "hex")
        );
        const input2 = Uint8Array.from(
            Buffer.from("202122232425262728292a2b2c2d2e2f202122232425262728292a2b2c2d2e2f", "hex")
        );
        const answer = bufferAnswer(await blake2b(concatBytes([input0, input1, input2, input0, input1])));
        const response = bufferResponse(await blake2bContract.blake2b([input0, input1, input2, input0, input1]));
        expect(response).to.deep.equal(answer);

        const response2 = bufferResponse(await blake2bContract.blake2bFive([input0, input1, input2, input0, input1]));
        expect(response2).to.deep.equal(answer);
    });

    it("hash large chunk", async () => {
        const input = Array(20).fill(
            Uint8Array.from(
                Buffer.from("000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f", "hex")
            )
        );

        const answer = bufferAnswer(await blake2b(concatBytes(input)));
        const response = bufferResponse(await blake2bContract.blake2b(input));
        expect(response).to.deep.equal(answer);
    });
});
