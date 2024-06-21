import { deployMockContract, MockContract } from "@clrfund/waffle-mock-contract";
import { parseEther, Signer } from "ethers";
import env = require("hardhat");

async function deployMock(owner: Signer, name: string): Promise<MockContract> {
    const abi = (await env.artifacts.readArtifact(name)).abi;
    return await deployMockContract(owner, abi);
}

async function transferBalance(owner: Signer, receiver: string, value: string) {
    const amount = parseEther(value);

    console.log("before send");
    console.log(receiver);
    console.log(owner);

    const tx = await owner.sendTransaction({
        to: receiver,
        value: amount,
        gasLimit: 210000,
    });

    await tx.wait();
}

export { deployMock, transferBalance };
