# 0G Storage Contract 

## Introduction

The 0g-storage-contracts system is tasked with the management of data submission for 0g storage, Proof of Random Access (PoRA) mining, and the economic model associated with these processes. It features a modular design that allows for various implementations of its components, including:

### Flow

The Flow module is responsible for receiving user storage requests along with their metadata, maintaining the overall storage Merkle root, and generating mining tasks in period.

### Market

Upon receiving a submission from a user, the Flow module notifies the Market contract. If the Market contract determines that the user has not paid sufficient fees, it will revert the entire transaction.

It is important to note that the payment of fees and the submission of data are independent steps. The Flow does not automatically pay the Market when submitting data. This design allows for more flexible Market logic, such as multi-currency payments. Some contracts, like FixedPriceFlow, merge these two steps into a single transaction.

Implementations of the Market include:
- **FixedPrice**: Charges a fixed price for submissions. Users can voluntarily pay a tip to incentivize more miners for storage.

### Reward

The Market can transfer a portion of the balance to the Reward module and inform it about which segment of data the fees are for.

Besides, after a mining task is verified, the Flow informs the Reward about the pricing chunk hit by the miner's PoRA and requests the reward. The specific amount of the reward is determined by the Reward contract.

Implementations of the Reward include:
- **ChunkDecayReward**: The earliest economic model design, where each pricing chunk has a separate reward pool composed of various fees paid by users during data submission. The fees are released at a half-life rate of 25 years, allowing miners to extract half of the remaining unlocked rewards with each mining hit.
- **ChunkLinearReward**: A variation of the previous design that changes the release method to a fixed-time linear release, aiming to address the issue of low capital utilization.
- **OnePoolReward**: Maintains a single reward pool within a mining time window (e.g., only data submitted in the last three months is eligible for mining). This design focuses on a singular, consolidated reward pool for the specified time window.

### Mine

Responsible for validating mining submissions and distributing rewards.

## Compile

```shell
yarn
yarn build
```

## Deploy contract

If the economic model is not enabled, data submissions and mining will not involve token transfers. If enabled, `FixedPrice` will be selected as the market, and `OnePoolReward` as the Reward.

Use the following command for deployment with economic model:

```
yarn deploy-market-enabled <network>
```

For deployment without economic model:

```
yarn deploy-no-market <network>
```

To export all contract addresses of a deployment into a single file:
```
yarn hardhat export --network <network> --export <filename>
``` 

### Deployment Configurations

You can create a custom configuration file for a network under [networks](src/networks/) folder, then put the network name and the configuration struct as entry in `GlobalConfig` mapping in [config.ts](src/config.ts).

See configuration for [zg](src/networks/zerog_contract_config.ts) network as reference.

### targetnetwork

You have several options for the target network, which you can modify in `hardhat.config.ts`:

- **localtest**: For local testing environments.
- **zg**: For deploying on Zero Gravity network.

When deploying, ensure that your environment is properly configured with the necessary variables and network settings to match your deployment goals. This modular and flexible approach allows for tailored deployments that fit the specific needs of your project.

## Standard Operating Procedure for Contract Deployment/Upgrade

In this section, we will describe how to maintain information related to contract deployment and upgrades.

### Deployments

After the first contract deployment following the above procedure, a folder named after the corresponding network will be created in the `deployments/` directory under the root. This folder will contain all the information about the deployed contracts, including their addresses and ABI, and each time a new contract is deployed on this network, the deployments will also be updated. The deployments need to be properly preserved and updated, such as by setting up a separate Git repository.

### Upgrade

We use the Hardhat task defined in [upgrade](src/tasks/upgrade.ts) to perform contract upgrades and maintenance.

First, after each contract deployment or upgrade, we need to execute the `upgrade:forceImportAll` task to persist the current version of the contract locally. Note that when executing the force import, you must ensure that the locally generated artifacts correspond to the version of the contract. The generated version files are saved in `.openzeppelin/`.

Then, when we modify a contract and want to upgrade, we need to check for conflicts between the new contract and the previously deployed version (such as incompatible storage layout). We can use `upgrade:validate` to validate it. Similarly, this step needs to ensure that the local artifacts are compiled from the new version of the contract.

Finally, after completing the above checks, you can execute the contract upgrade transaction using the `upgrade` task. Once the upgrade is complete, we have deployed a new implementation contract, so don't forget to execute `forceImportAll` to update the local contract deployment version information and save the updated `deployments/` folder.

### Overall Workflow

1. First contract deployments;
2. Execute `forceImportAll`, save the generated version files and `deployments/`;
3. Prepare an upgrade;
4. Compile contracts, validate upgrade and then execute;
5. Execute `forceImportAll`, save the modified version files and `deployments/`;
6. repeat 3 to 5.