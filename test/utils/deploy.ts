import { Signer } from "ethers";
import { MockContract } from "ethereum-waffle";
import env = require("hardhat");
const { waffle } = env;

async function deployMock(owner: Signer, name: string): Promise<MockContract> {
  let abi = (await env.artifacts.readArtifact(name)).abi;
  return await waffle.deployMockContract(owner, abi);
}

export { deployMock };
