import chai, { expect } from "chai";
import { Contract } from "ethers";
import { ethers, waffle } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployMock } from "./utils/deploy";

import type { Flow, IERC20 } from "../typechain-types";
import { MockContract } from "ethereum-waffle";

describe.skip("ZeroGStorage Flow", function () {
  let owner: SignerWithAddress;
  before(async () => {
    [owner] = await ethers.getSigners();
  });

  let flow: Flow;
  let token: IERC20;
  let mockCashier: MockContract;
  beforeEach(async () => {
    let erc20ABI = await ethers.getContractFactory("MockToken");
    token = await erc20ABI.deploy();

    const [owner] = await ethers.getSigners();
    mockCashier = await deployMock(owner, "Cashier");
    await mockCashier.mock.chargeFee.returns();

    let flowABI = await ethers.getContractFactory("Flow");
    flow = await flowABI.deploy(mockCashier.address, 100, 0); /* token.address */
  });

  it("submit", async () => {
    let root = Buffer.from(
      "ccc2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
      "hex"
    );
    console.log("before submit");
    await flow.submit({ length: 256 * 256, tags: Buffer.from(''), nodes: [{ root, height: 8 }] });
    console.log("after submit");
  });
});
