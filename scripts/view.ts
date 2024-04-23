import { Signer } from "ethers";
import { SigningKey, arrayify, parseBytes32String } from "ethers/lib/utils";
import fs from "fs";
import { ethers } from "hardhat";
import { FixedPriceFlow, OnePoolReward, PoraMine } from "../typechain-types";

async function contracts(me: Signer) {
  const mineABI = await ethers.getContractFactory("PoraMine", me);
  const mine = await mineABI.attach("0x8B9221eE2287aFBb34A7a1Ef72eB00fdD853FFC2");

  const flowABI = await ethers.getContractFactory("FixedPriceFlow", me);
  const flow = await flowABI.attach("0x22C1CaF8cbb671F220789184fda68BfD7eaA2eE1");

  const bookAddr = await mine.book();
  const bookABI = await ethers.getContractFactory("AddressBook", me);
  const book = await bookABI.attach(bookAddr);

  const rewardABI = await ethers.getContractFactory("OnePoolReward", me);
  const reward = await rewardABI.attach(await book.reward());

  return { mine, flow, book, reward }
}

async function getBlockNumber() {
  return (await ethers.provider.getBlock("latest")).number
}

async function printContext(flow: FixedPriceFlow, batches: number = 10) {
  const [firstBlock_, blocksPerEpoch_] = await Promise.all([flow.firstBlock(), flow.blocksPerEpoch()])
  const [firstBlock, blocksPerEpoch] = [firstBlock_.toNumber(), blocksPerEpoch_.toNumber()]

  const n = await getBlockNumber();
  // const parser = new ethers.utils.Interface([flow.interface.getEvent("NewEpoch")]);

  for (let i = n; i > n - 10000 * batches; i -= 10000) {
    if (i < firstBlock) {
      return;
    }
    const events = await flow.queryFilter(flow.filters.NewEpoch(), i - 10000, i);
    for (const event of events.reverse()) {
      const args = event.args;
      const epoch = parseInt(event.topics[2], 16);
      const epochStart = firstBlock + blocksPerEpoch * epoch;

      const timestamp = (await ethers.provider.getBlock(epochStart)).timestamp;
      const timeString = (new Date(timestamp * 1000)).toLocaleString();

      console.log("%d:\t%d = %d + %d\t%s\t%s\t%s\tlength: %d", epoch, event.blockNumber, epochStart, event.blockNumber - epochStart, args.context, args.sender, timeString, args.flowLength.toNumber())
    }
  }
}

async function printReward(reward: OnePoolReward, batches: number = 10) {
  const n = await getBlockNumber();

  for (let i = n; i > n - 10000 * batches; i -= 10000) {
    const events = await reward.queryFilter(reward.filters.DistributeReward(), i - 10000, i);
    for (const event of events.reverse()) {

      const [tx, receipt] = await Promise.all([event.getTransaction(), event.getTransactionReceipt()]);
      console.log("%d\tGas: %d (%d)\t%s", event.blockNumber, receipt.gasUsed.toNumber(), tx.gasLimit.toNumber(), event.transactionHash)

    }
  }
}

async function printNextEpoch(flow: FixedPriceFlow) {
  const [firstBlock_, blocksPerEpoch_, epoch_] = await Promise.all([flow.firstBlock(), flow.blocksPerEpoch(), flow.epoch()])
  const [firstBlock, blocksPerEpoch, epoch] = [firstBlock_.toNumber(), blocksPerEpoch_.toNumber(), epoch_.toNumber()]
  const nextEpoch = firstBlock + blocksPerEpoch * (epoch + 1);
  const currentBlock = await getBlockNumber();
  const context = await flow.callStatic.makeContextWithResult();

  console.log("Current Block: %d", currentBlock)
  console.log("current length: %d", context.flowLength.toNumber())
  console.log("current flow root: %s", context.flowRoot)
  console.log("first block: %d", firstBlock)
  console.log("blocks per epoch: %d", blocksPerEpoch)
  console.log("epoch: %d", epoch)
  console.log("next epoch start: %d (%d blocks left)", nextEpoch, nextEpoch - currentBlock);
}

async function updateContext(flow: FixedPriceFlow) {
  const tx = await flow.makeContext();
  const receipt = await tx.wait();
  console.log(receipt)
}

async function printMineConfig(mine: PoraMine) {
  const [sealDataEnabled, dataProofEnabled, fixedQuality] = await Promise.all([mine.sealDataEnabled(), mine.dataProofEnabled(), mine.fixedQuality()])
  console.log("SealDataEnabled:", sealDataEnabled)
  console.log("DataProofEnabled:", sealDataEnabled)
  console.log("FixedQuality:", fixedQuality)
}

async function main() {
  const [owner, me, me2] = await ethers.getSigners();

  const { mine, flow, book, reward } = await contracts(me2);

  // console.log(me.address)
  // console.log(await mine.minerIds(me.address))
  // console.log(me2.address)
  // console.log(await mine.minerIds(me2.address))
  // const tx = await mine.registMiner(arrayify("0x308a6e102a5829ba35e4ba1da0473c3e8bd45f5d3ffb91e31adb43f25463ddd1"))
  // console.log(await tx.wait())
  // console.log(await mine.minerIds(me2.address))

  // await updateContext(flow);
  await printNextEpoch(flow)
  // await printContext(flow, 2)
  await printReward(reward)
  // await printMineConfig(mine)
  // console.log(await flow.getContext())



  

  // const tx = await reward.claimMineReward(0, owner.address)
  // console.log("send tx")
  // console.log(tx)
  // console.log(await tx.wait())

  console.log((await mine.lastMinedEpoch()).toNumber())
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });