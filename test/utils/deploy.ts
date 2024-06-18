import { MockContract } from "ethereum-waffle";
import { Signer, utils } from "ethers";
import { AddressBook } from "../../typechain-types";
import env = require("hardhat");
const { waffle } = env;

async function deployMock(owner: Signer, name: string): Promise<MockContract> {
    let abi = (await env.artifacts.readArtifact(name)).abi;
    return await waffle.deployMockContract(owner, abi);
}

async function deployAddressBook(params: {
    flow: string;
    market?: string;
    reward?: string;
    mine?: string;
}): Promise<AddressBook> {
    let abi = await env.ethers.getContractFactory("AddressBook");
    let flow_ = params.flow;
    let market_ = params.market || "0x0000000000000000000000000000000000000000";
    let reward_ = params.reward || "0x0000000000000000000000000000000000000000";
    let mine_ = params.mine || "0x0000000000000000000000000000000000000000";

    return await abi.deploy(flow_, market_, reward_, mine_);
}

async function transferBalance(owner: Signer, receiver: string, value: string) {
    const amount = utils.parseEther(value);

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

export { deployMock, deployAddressBook, transferBalance };
