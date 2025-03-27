// @ts-nocheck

import { Signer } from "ethers";
import { ethers } from "hardhat";
import { ChunkLinearReward, FixedPriceFlow, PoraMine } from "../../typechain-types";
import { TypedContractEvent, TypedEventLog } from "../../typechain-types/common";

import { NewEpochEvent } from "../../typechain-types/contracts/dataFlow/Flow";
import { NewSubmissionEvent } from "../../typechain-types/contracts/miner/Mine.sol/PoraMine";
import { DistributeRewardEvent } from "../../typechain-types/contracts/reward/ChunkLinearReward";

type TypedNewEpochEvent = TypedContractEvent<
    NewEpochEvent.InputTuple,
    NewEpochEvent.OutputTuple,
    NewEpochEvent.OutputObject
>;
type TypedDistributeRewardEvent = TypedContractEvent<
    DistributeRewardEvent.InputTuple,
    DistributeRewardEvent.OutputTuple,
    DistributeRewardEvent.OutputObject
>;
type TypedNewSubmissionEvent = TypedContractEvent<
    NewSubmissionEvent.InputTuple,
    NewSubmissionEvent.OutputTuple,
    NewSubmissionEvent.OutputObject
>;
const u256_max = 1n << 256n;

interface ViewContracts {
    mine: PoraMine;
    flow: FixedPriceFlow;
    reward: ChunkLinearReward;
}

async function contracts(me: Signer): Promise<ViewContracts> {
    const mine = await ethers.getContractAt("PoraMine", "0x6815F41019255e00D6F34aAB8397a6Af5b6D806f", me);

    const flow = await ethers.getContractAt("FixedPriceFlow", "0xbD2C3F0E65eDF5582141C35969d66e34629cC768", me);

    const reward = await ethers.getContractAt("ChunkLinearReward", "0x51998C4d486F406a788B766d93510980ae1f9360", me);

    return { mine, flow, reward };
}

async function getBlockNumber() {
    return (await ethers.provider.getBlock("latest")).number;
}

async function printStatus(flow: FixedPriceFlow, mine: PoraMine) {
    const latestBlock = await ethers.provider.getBlock("latest");
    console.log("\n============= Blockchain information =============");
    const currentBlock = latestBlock.number;
    const timestamp = latestBlock.timestamp;
    console.log("current block number: %d", currentBlock);
    console.log("current time: %s", new Date(timestamp * 1000).toString());
    // console.log("gas price: %d", gasPrice);
    console.log("gas price: %s ", (await ethers.provider.getFeeData()).gasPrice);

    const context = await flow.makeContextWithResult.staticCall();
    console.log("\n============= Flow information =============");
    console.log("current length: %d (%d pricing chunks)", context.flowLength, context.flowLength / 33554432n);
    console.log("current flow root: %s", context.flowRoot);
    console.log("current context digest: %s", context.digest);

    const [firstBlock, blocksPerEpoch, epoch] = await Promise.all([
        flow.firstBlock(),
        flow.blocksPerEpoch(),
        flow.epoch(),
    ]);
    console.log("\n============= Epoch information =============");
    const nextEpoch = firstBlock + blocksPerEpoch * (epoch + 1n);
    console.log("first block: %d", firstBlock);
    console.log("blocks per epoch: %d", blocksPerEpoch);
    console.log("epoch: %d (expected %d)", epoch, context.epoch);
    console.log(
        "current epoch time: %d / %d",
        BigInt(currentBlock) - (firstBlock + blocksPerEpoch * epoch),
        blocksPerEpoch
    );
    console.log("next epoch start: %d (%d blocks left)", nextEpoch, nextEpoch - BigInt(currentBlock));

    const [
        poraTarget,
        currentSubmissions,
        targetSubmissions,
        targetSubmissionsNextEpoch,
        targetMineBlocks,
        lastMinedEpoch,
        minimumQuality,
        canSubmit,
    ] = await Promise.all([
        mine.poraTarget(),
        mine.currentSubmissions(),
        mine.targetSubmissions(),
        mine.targetSubmissionsNextEpoch(),
        mine.targetMineBlocks(),
        mine.lastMinedEpoch(),
        mine.minDifficulty(),
        mine.canSubmit.staticCall(),
    ]);
    console.log("\n============= Mine information =============");
    console.log("target quality", u256_max / poraTarget);
    console.log("minimum quality", minimumQuality);
    console.log("current submissions: %d / %d", currentSubmissions, targetSubmissions);
    console.log("target submissions for next epoch: %d", targetSubmissionsNextEpoch);
    console.log("target mine blocks: %d", targetMineBlocks);
    console.log("last mined epoch: %d", lastMinedEpoch);
    console.log("can submit:", canSubmit);

    const [sealDataEnabled, dataProofEnabled, fixedDifficulty] = await Promise.all([
        mine.sealDataEnabled(),
        mine.dataProofEnabled(),
        mine.fixedDifficulty(),
    ]);
    console.log("\n============= Mine config =============");
    console.log("SealDataEnabled:", sealDataEnabled);
    console.log("DataProofEnabled:", sealDataEnabled);
    console.log("FixedDifficulty:", fixedDifficulty);

    console.log("<<<<<<<< Done <<<<<<<<<<\n");
}

async function queryEvents<TCEvent extends TypedContractEvent>(
    blocks: number,
    contract: BaseContract,
    filter: TypedDeferredTopicFilter<TCEvent>,
    callback: (eventLog: TypedEventLog<TCEvent>) => Promise<void>
) {
    const GET_LOGS_RANGE = 1000;
    const n = await getBlockNumber();
    let i = n;
    const startBlock = Math.max(0, n - blocks + 1);

    while (i > startBlock) {
        const queryEnd = i;
        const queryStart = Math.max(startBlock, i - GET_LOGS_RANGE + 1);
        const events = await contract.queryFilter(filter, i - GET_LOGS_RANGE + 1, i);
        for (const event of events.reverse()) {
            await callback(event);
        }
        i -= GET_LOGS_RANGE;
    }
}

async function printContext(flow: FixedPriceFlow, blocks: number = 1000) {
    console.log("====== New Epoch Events (last %d blocks) ======", blocks);

    const [firstBlock, blocksPerEpoch] = await Promise.all([flow.firstBlock(), flow.blocksPerEpoch()]);

    await queryEvents<TypedNewEpochEvent>(blocks, flow, flow.filters.NewEpoch(), async function (event) {
        const args = event.args;
        const epoch = event.args.index;
        const epochStart = Number(firstBlock + blocksPerEpoch * epoch);

        const timestamp =
            (await ethers.provider.getBlock(epochStart))?.timestamp ??
            (() => {
                throw new Error("Failed to fetch the block");
            })();
        const timeString = new Date(timestamp * 1000).toLocaleString();

        console.log(
            "Epoch %d:\t Activated at %d (activate block) = %d (start block) + %d (block delay) \tcontext digest: %s\tsender: %s\tactivate time: %s\tflow length: %d",
            epoch,
            event.blockNumber,
            epochStart,
            event.blockNumber - epochStart,
            args.context,
            args.sender,
            timeString,
            args.flowLength
        );
    });
    console.log("<<<<<<<< Done <<<<<<<<<<\n");
}

async function printReward(reward: ChunkLinearReward, blocks: number = 1000) {
    console.log("====== Reward Distribution Events (last %d blocks) ======", blocks);
    await queryEvents<TypedDistributeRewardEvent>(
        blocks,
        reward,
        reward.filters.DistributeReward(),
        async function (event) {
            const [tx, receipt] = await Promise.all([event.getTransaction(), event.getTransactionReceipt()]);
            console.log(
                "Reward distributed at block %d\tGas: %d (%d)\ttx hash: %s",
                event.blockNumber,
                receipt.gasUsed,
                tx.gasLimit,
                event.transactionHash
            );
        }
    );
    console.log("<<<<<<<< Done <<<<<<<<<<\n");
}

async function printMineSubmissions(mine: PoraMine, blocks: number = 1000) {
    console.log("====== Mine Submission Events (last %d blocks) ======", blocks);
    await queryEvents<TypedNewSubmissionEvent>(blocks, mine, mine.filters.NewSubmission(), async function (event) {
        console.log(
            "Mine submission, epoch: %d\tindex: %d,\tposition: %d - %d\ttx hash: %s",
            event.args.epoch,
            event.args.epochIndex,
            event.args.recallPosition / 33554432n,
            event.args.recallPosition % 33554432n,
            event.transactionHash
        );
    });
    console.log("<<<<<<<< Done <<<<<<<<<<\n");
}

async function printRewardPool(reward: ChunkLinearReward, chunks: number) {
    const toDate = function (timestamp) {
        const date = new Date(Number(timestamp * 1000n));
        return date.toISOString();
    };
    const base = 1000000000000000n;
    console.log("====== Reward pool ======");

    const [releaseSeconds, baseReward, totalBaseReward, firstRewardableChunk] = await Promise.all([
        reward.releaseSeconds(),
        reward.baseReward(),
        reward.totalBaseReward(),
        reward.firstRewardableChunk(),
    ]);

    console.log("Note: 1000 mZG = 1 ZG");
    console.log(`release days: ${releaseSeconds / 86400n}`);
    console.log(`base reward: ${baseReward / base} mZG`);
    console.log(`total base reward: ${totalBaseReward / base} mZG`);
    console.log(`first rewardable chunk: ${firstRewardableChunk}`);

    for (let i = firstRewardableChunk; i < chunks; i++) {
        const res = await reward.rewards(i);
        console.log(
            `[Pool ${i}]\tlocked: ${res.lockedReward / base} mZG,\tclaimable: ${
                res.claimableReward / base
            } mZG,\tdistributed: ${res.distributedReward / base} mZG,\tstart time: ${toDate(
                res.startTime
            )},\tlast update: ${toDate(res.lastUpdate)}`
        );
    }
    const res = await reward.rewards(chunks);
    console.log(
        `[Pool next]\treward: ${res.lockedReward / base},\tclaimable: ${res.claimableReward / base},\tdistributed: ${
            res.distributedReward / base
        },\tstart time: ${toDate(res.startTime)},\tlast update: ${toDate(res.lastUpdate)}`
    );
    console.log("<<<<<<<< Done <<<<<<<<<<\n");
}

async function updateContext(flow: FixedPriceFlow) {
    const tx = await flow.makeContext();
    const receipt = await tx.wait();
    console.log(receipt);
}

async function main() {
    const [owner, me, me2] = await ethers.getSigners();

    const { mine, flow, reward } = await contracts(me2);
    await printStatus(flow, mine);
    await printContext(flow);
    await printReward(reward);
    await printMineSubmissions(mine);
    const pricingChunks = Number((await flow.makeContextWithResult.staticCall()).flowLength / 33554432n);
    await printRewardPool(reward, pricingChunks);
    // await updateContext(flow);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
