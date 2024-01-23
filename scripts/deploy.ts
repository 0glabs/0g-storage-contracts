import fs from "fs";
import { ethers } from "hardhat";

async function main() {
  let erc20ABI = await ethers.getContractFactory("MockToken");
  let token = await erc20ABI.deploy();

  let flowABI = await ethers.getContractFactory("Flow");
  const blocksPerEpoch = 1_000_000;
  let flow = await flowABI.deploy(token.address, blocksPerEpoch, 0);

  await token.approve(flow.address, 1e9);

  let mineABI = await ethers.getContractFactory("PoraMineTest");
  // TODO: deploy new contracts
  let mine = await mineABI.deploy(flow.address, "0x0000000000000000000000000000000000000000", 7);

  const output = `token = '${token.address}'\nflow = '${flow.address}'\nPoraMine = '${mine.address}'`;

  console.log(output);
  fs.writeFileSync("./deploy/localtest.py", output);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
