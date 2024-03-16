# 0G Storage Contract 

## Introduction

The 0g-storage-contracts system is tasked with the management of data submission for 0g storage, Proof of Random Access (PoRA) mining, and the economic model associated with these processes. It features a modular design that allows for various implementations of its components, including:

### Flow

The Flow module is responsible for receiving user storage requests along with their metadata, maintaining the overall storage Merkle root, and generating mining tasks in period.

### Market

Upon receiving a submission from a user, the Flow module notifies the Market contract. If the Market contract determines that the user has not paid sufficient fees, it will revert the entire transaction.

It is important to note that the payment of fees and the submission of data are independent steps. The Flow does not automatically pay the Market when submitting data. This design allows for more flexible Market logic, such as multi-currency payments. Some contracts, like FixedPriceFlow, merge these two steps into a single transaction.

Implementations of the Market include:
- **Cashier**: An early design with extensive features, may not be suitable for current systems.
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
yarn compile
```

## Deploy contract

Use the following command for deployment

```
npx hardhat run scripts/deploy.ts --network <targetnetwork>
```

### Module Selection and Parameters

By setting environment variables, you can control the types of contracts deployed and their parameters.

- **BLOCKS_PER_EPOCH**: This variable determines how often the `makeContext` function needs to be called within each mining cycle, known as an Epoch. If this function is not called over several epochs, it may cause issues. By default, this value is set very high, meaning that the contract will not generate mining tasks. For mining tests, adjust it to a suitable size (recommended block count per hour).

- **ENABLE_MARKET**: Accepts `true` or `false`. If the economic model is not enabled, data submissions and mining will not involve token transfers. If enabled, `FixedPrice` will be selected as the market, and `OnePoolReward` as the Reward.

- **LIFETIME_MONTH**: Upon enabling the economic model, this controls the data storage validity period and the reward release cycle. The annual storage cost per GB is a constant in the contract named `ANNUAL_ZGS_TOKENS_PER_GB`.

### targetnetwork

You have several options for the target network, which you can modify in `hardhat.config.ts`:

- **localtest**: For local testing environments.
- **bsc**: For deploying on Binance Smart Chain Testnet.
- **conflux**: For deploying on the Conflux network eSpace Testnet.

When deploying, ensure that your environment is properly configured with the necessary variables and network settings to match your deployment goals. This modular and flexible approach allows for tailored deployments that fit the specific needs of your project.
