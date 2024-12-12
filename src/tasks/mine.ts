import { task, types } from "hardhat/config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

task("mine:show", "show contract params").setAction(async (_, hre) => {
    const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
    console.log(await mine.targetSubmissions());
    console.log(await mine.canSubmit.staticCall());
});

task("mine:setTargetSubmissions", "set target submissions")
    .addParam("n", "number of target submissions", undefined, types.int, false)
    .setAction(async (taskArgs: { n: number }, hre) => {
        const mine = await getTypedContract(hre, CONTRACTS.PoraMine);
        await (await mine.setTargetSubmissions(taskArgs.n)).wait();
        console.log(`set target submission to ${taskArgs.n}`);
    });
