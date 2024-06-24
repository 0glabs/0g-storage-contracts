import { task, types } from "hardhat/config";

task("codesize", "show codesize of the contracts")
    .addParam("contractname", "contract name", undefined, types.string, true)
    .setAction(async (taskArgs: { contractname: string }, hre) => {
        const contracts = await hre.artifacts.getAllFullyQualifiedNames();
        const ans = [];
        for (const contract of contracts) {
            const artifact = await hre.artifacts.readArtifact(contract);
            if (taskArgs.contractname && taskArgs.contractname !== artifact.contractName) continue;
            ans.push([
                artifact.contractName,
                Math.max(0, (artifact.deployedBytecode.length - 2) / 2),
                "bytes (max 24576)",
            ]);
        }
        ans.sort((a, b) => {
            if (a[1] > b[1]) return -1;
            if (a[1] < b[1]) return 1;
            return 0;
        });
        for (const x of ans) {
            if (Number(x[1]) > 0) console.log(`${x[0]}:\t${x[1]} ${x[2]}`);
        }
    });
