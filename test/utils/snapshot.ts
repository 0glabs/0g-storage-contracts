import hre = require("hardhat");

class Snapshot {
    snapshotId;
    constructor() {
        this.snapshotId = "";
    }

    async snapshot(): Promise<Snapshot> {
        this.snapshotId = await hre.network.provider.send("evm_snapshot", []);
        return this;
    }

    async revert() {
        await hre.network.provider.send("evm_revert", [this.snapshotId]);
        await this.snapshot();
    }
}

async function increaseTime(seconds: number): Promise<number> {
    return await hre.network.provider.send("evm_increaseTime", [seconds]);
}

async function enableAutomine(): Promise<null> {
    return await hre.network.provider.send("evm_setAutomine", [true]);
}

async function disableAutomine(): Promise<null> {
    return await hre.network.provider.send("evm_setAutomine", [false]);
}

export { Snapshot, increaseTime, enableAutomine, disableAutomine };
