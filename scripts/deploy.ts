import fs from "fs";
import { ethers } from "hardhat";
import { predictContractAddress } from "./addressPredict";

const ZERO = "0x0000000000000000000000000000000000000000"

async function main() {
  const [owner] = await ethers.getSigners();

  const flowAddress = await predictContractAddress(owner, 1);
  const mineAddress = await predictContractAddress(owner, 2);

  const bookABI = await ethers.getContractFactory("AddressBook");
  const book = await bookABI.deploy(flowAddress, ZERO, ZERO, mineAddress);  

  const flowABI = await ethers.getContractFactory("Flow");
  const blocksPerEpoch = 1_000_000;
  const flow = await flowABI.deploy(book.address, blocksPerEpoch, 0);

  const blockNumber = await ethers.provider.getBlockNumber();
  const account = owner.address;

  const mineABI = await ethers.getContractFactory("PoraMineTest");
  const mine = await mineABI.deploy(book.address, 3);


  const output = `flow = '${flow.address}'\nPoraMine = '${mine.address}'\nblockNumber = ${blockNumber}\naccount = '${account}'`;

  console.log(output);
  fs.writeFileSync("./deploy/localtest.py", output);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
