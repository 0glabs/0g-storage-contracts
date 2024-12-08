import { task } from "hardhat/config";
import { getConfig } from "../config";
import { CONTRACTS, getTypedContract } from "../utils/utils";

task("flow:show", "show contract params").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    // const signer = await hre.ethers.getSigner((await hre.getNamedAccounts()).deployer);
    // testnet turbo first impl
    // const flow = CONTRACTS.FixedPriceFlow.factory.connect("0x61450afb8F99AB3D614a45cb563C61f59d9DD026", signer);
    // testnet standard first impl
    // const flow = CONTRACTS.FixedPriceFlow.factory.connect("0x1F7A30Cd62c4132B6C521B8F79e7aE0046A4F307", signer);
    console.log(await flow.getContext());
    console.log(await flow.blocksPerEpoch());
    console.log(await flow.firstBlock());
    console.log(await flow.rootHistory());
});

task("flow:setparams", "set contract params").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    const config = getConfig(hre.network.name);
    await (await flow.setParams(config.blocksPerEpoch, config.firstBlock, config.rootHistory)).wait();
    console.log(`done.`);
});

task("flow:pause", "pause contract").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    await (await flow.pause()).wait();
    console.log(`done.`);
});

task("flow:unpause", "unpause contract").setAction(async (_, hre) => {
    const flow = await getTypedContract(hre, CONTRACTS.FixedPriceFlow);
    await (await flow.unpause()).wait();
    console.log(`done.`);
});
