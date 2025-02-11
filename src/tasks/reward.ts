import { task, types } from "hardhat/config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

task("reward:donate", "set extra total base reward")
    .addParam("amnt", "amount of donation", undefined, types.string, false)
    .setAction(async (taskArgs: { amnt: string }, hre) => {
    const reward = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);
    await (await reward.donate({ value: hre.ethers.parseEther(taskArgs.amnt) })).wait();
    console.log(`donated ${taskArgs.amnt}`);
});

task("reward:setBaseReward", "set extra base reward")
.addParam("amnt", "amount of base reward", undefined, types.string, false)
.setAction(async (taskArgs: { amnt: string }, hre) => {
    const reward = await getTypedContract(hre, CONTRACTS.ChunkLinearReward);
    await (await reward.setBaseReward(hre.ethers.parseEther(taskArgs.amnt))).wait();
    console.log(`set base reward to ${taskArgs.amnt}`);
});
