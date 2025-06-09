import { task, types } from "hardhat/config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

task("mine:show", "show contract params").setAction(async (_, hre) => {
    const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
    console.log(await mine.targetSubmissions());
    console.log(await mine.minDifficulty());
    console.log(await mine.poraTarget());
    console.log(await mine.canSubmit.staticCall());
});

task("mine:setTargetSubmissions", "set target submissions")
    .addParam("n", "number of target submissions", undefined, types.int, false)
    .setAction(async (taskArgs: { n: number }, hre) => {
        const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
        await (await mine.setTargetSubmissions(taskArgs.n)).wait();
        console.log(`set target submission to ${taskArgs.n}`);
    });

task("mine:setMinDifficulty", "set min difficulty")
    .addParam("min", "number of min difficulty", undefined, types.bigint, false)
    .setAction(async (taskArgs: { min: bigint }, hre) => {
        const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
        await (await mine.setMinDifficulty(taskArgs.min)).wait();
        console.log(`set min difficulty to ${taskArgs.min}`);
    });

task("mine:setNumSubtasks", "set num subtasks")
    .addParam("n", "number of num subtasks", undefined, types.int, false)
    .setAction(async (taskArgs: { n: number }, hre) => {
        const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
        await (await mine.setNumSubtasks(taskArgs.n)).wait();
        console.log(`set num subtasks to ${taskArgs.n}`);
    });
