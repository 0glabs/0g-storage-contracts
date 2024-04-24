import fs from "fs";
import { ethers } from "hardhat";
import { predictContractAddress } from "./addressPredict";

function parseBool(str: string) {
  if (str.toLowerCase() === "true") {
    return true;
  } else if (str.toLowerCase() === "false") {
    return false;
  }
}

const enableMarket = parseBool(process.env["ENABLE_MARKET"] || "false");
const blocksPerEpoch = parseInt(process.env["BLOCKS_PER_EPOCH"] || "1000000000");
const lifetimeMonth = parseInt(process.env["LIFETIME_MONTH"] || "3");
const initHashRate = parseInt(process.env["INIT_HASH_RATE"] || "1000");

const ZERO = "0x0000000000000000000000000000000000000000"

function writeDeployResult(output: string) {
  if (!fs.existsSync("./deploy")) {
    fs.mkdirSync("./deploy", { recursive: true });
  }
  fs.writeFileSync("./deploy/localtest.py", output);
}

async function deploySimpleMarket() {
  const [owner] = await ethers.getSigners();

  const mineAddress = await predictContractAddress(owner, 1);
  const marketAddress = await predictContractAddress(owner, 2);
  const rewardAddress = await predictContractAddress(owner, 3);
  const flowAddress = await predictContractAddress(owner, 4);

  const bookABI = await ethers.getContractFactory("AddressBook");
  const book = await bookABI.deploy(flowAddress, marketAddress, rewardAddress, mineAddress);

  const mineABI = await ethers.getContractFactory("PoraMine");
  const mine = await mineABI.deploy(book.address, initHashRate, 20, 0);

  const marketABI = await ethers.getContractFactory("FixedPrice");
  const market = await marketABI.deploy(book.address, lifetimeMonth);

  const rewardABI = await ethers.getContractFactory("OnePoolReward");
  const reward = await rewardABI.deploy(book.address, lifetimeMonth);

  const flowABI = await ethers.getContractFactory("FixedPriceFlow");
  const flow = await flowABI.deploy(book.address, BigInt(blocksPerEpoch), 0);

  const blockNumber = await ethers.provider.getBlockNumber();
  const account = owner.address;


  const output = `flow = '${flow.address}'\nPoraMine = '${mine.address}'\nmarket = '${market.address}'\nreward = '${reward.address}'\nblockNumber = ${blockNumber}\naccount = '${account}'`;

  console.log(output);
  writeDeployResult(output);
}

async function deployNoMarket() {
  const [owner] = await ethers.getSigners();

  const flowAddress = await predictContractAddress(owner, 1);
  const mineAddress = await predictContractAddress(owner, 2);

  const bookABI = await ethers.getContractFactory("AddressBook");
  const book = await bookABI.deploy(flowAddress, ZERO, ZERO, mineAddress);

  const flowABI = await ethers.getContractFactory("Flow");
  const flow = await flowABI.deploy(book.address, BigInt(blocksPerEpoch), 0);

  const blockNumber = await ethers.provider.getBlockNumber();
  const account = owner.address;

  const mineABI = await ethers.getContractFactory("PoraMineTest");
  const mine = await mineABI.deploy(book.address, 0);

  const output = `flow = '${flow.address}'\nPoraMine = '${mine.address}'\nblockNumber = ${blockNumber}\naccount = '${account}'`;

  console.log(output);
  writeDeployResult(output);
}

async function main() {
  if (enableMarket) {
    await deploySimpleMarket();
  } else {
    await deployNoMarket();
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
