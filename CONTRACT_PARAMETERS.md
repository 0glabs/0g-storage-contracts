# Contract Parameters Documentation

This document outlines all configurable pa3. **Runtime Configuration**:

-   [ ] Set appropriate service fee rates
-   [ ] Configure treasury addresses
-   [ ] Set mining parameters for launch
-   [ ] Verify all role assignments

4. **Parameter Relationships**:
    - [ ] Mining parameters are consistent
    - [ ] Reward economics are balancedhe 0G Storage smart contracts, including initialization parameters, runtime configuration options, and immutable deployment settings.

---

## Contract Parameters Overview

### 1. **PoraMine Contract** (`contracts/miner/Mine.sol`)

#### **Constructor Parameters**

| Parameter  | Type   | Description                   | Default Values                                                                 | Changeable |
| ---------- | ------ | ----------------------------- | ------------------------------------------------------------------------------ | ---------- |
| `settings` | `uint` | Bit flags for mining features | Bitwise flags: NO_DATA_SEAL (0x1), NO_DATA_PROOF (0x2), FIXED_DIFFICULTY (0x4) | No         |

#### **Initialization Parameters**

| Parameter    | Type      | Description               | Default Value                          | Changeable |
| ------------ | --------- | ------------------------- | -------------------------------------- | ---------- |
| `difficulty` | `uint`    | Initial mining difficulty | Used to calculate initial `poraTarget` | No         |
| `flow_`      | `address` | Flow contract address     | -                                      | No         |
| `reward_`    | `address` | Reward contract address   | -                                      | No         |

#### **Default Initialized Values**

| Parameter                    | Type     | Value | Description                            | Changeable |
| ---------------------------- | -------- | ----- | -------------------------------------- | ---------- |
| `targetMineBlocks`           | `uint`   | 100   | Target blocks for mining window        | Yes        |
| `targetSubmissions`          | `uint`   | 10    | Target submissions per epoch           | Yes        |
| `targetSubmissionsNextEpoch` | `uint`   | 10    | Target submissions for admin to change and take effect on next epoch      | Yes        |
| `difficultyAdjustRatio`      | `uint`   | 20    | Difficulty adjustment smoothing factor | Yes        |
| `maxShards`                  | `uint64` | 4    | Maximum shards for storage             | Yes        |
| `nSubtasks`                  | `uint`   | 1     | ?                                      | Yes        |

targetMineBlocks = submission window = 10min -> n blocks

nSubtasks needs to add logic to increase step time

---

### 2. **Flow Contract** (`contracts/dataFlow/Flow.sol`)

#### **Constructor Parameters**

| Parameter      | Type   | Description                                  | Changeable |
| -------------- | ------ | -------------------------------------------- | ---------- |
| `deployDelay_` | `uint` | Delay before contract activation (immutable) | No         |

#### **Initialization Parameters**

| Parameter         | Type      | Description             | Changeable |
| ----------------- | --------- | ----------------------- | ---------- |
| `market_`         | `address` | Market contract address | No         |
| `blocksPerEpoch_` | `uint`    | Blocks per mining epoch | No         |

#### **Internal Parameters** (set once during initialization)

| Parameter     | Type      | Description                               | Default                         | Changeable |
| ------------- | --------- | ----------------------------------------- | ------------------------------- | ---------- |
| `firstBlock`  | `uint`    | Block number when contract becomes active | `block.number + deployDelay`    | No         |
| `rootHistory` | `address` | Digest history contract                   | Auto-created with 1000 capacity | No         |

#### **Constants**

| Parameter               | Type   | Value | Description               | Changeable |
| ----------------------- | ------ | ----- | ------------------------- | ---------- |
| `MAX_DEPTH`             | `uint` | 64    | Maximum merkle tree depth | No         |
| `ROOT_AVAILABLE_WINDOW` | `uint` | 1000  | Root history capacity     | No         |

---

### 3. **ChunkRewardBase Contract** (`contracts/reward/ChunkRewardBase.sol`)

#### **Initialization Parameters**

| Parameter | Type      | Description             | Changeable |
| --------- | --------- | ----------------------- | ---------- |
| `market_` | `address` | Market contract address | No         |
| `mine_`   | `address` | Mine contract address   | No         |

#### **Runtime Configurable Parameters** (PARAMS_ADMIN_ROLE)

| Function            | Parameter     | Type      | Description                                | Changeable |
| ------------------- | ------------- | --------- | ------------------------------------------ | ---------- |
| `setBaseReward`     | `baseReward_` | `uint`    | Base reward amount per mining claim        | Yes        |
| `setServiceFeeRate` | `bps`         | `uint`    | Service fee rate in basis points (0-10000) | Yes        |
| `setTreasury`       | `treasury_`   | `address` | Treasury address for service fees          | Yes        |

---

### 4. **ChunkDecayReward Contract** (`contracts/reward/ChunkDecayReward.sol`)

#### **Constructor Parameters**

| Parameter               | Type     | Description                                  | Changeable |
| ----------------------- | -------- | -------------------------------------------- | ---------- |
| `annualMilliDecayRate_` | `uint16` | Annual decay rate in milli-units (immutable) | No         |

_Inherits all parameters from ChunkRewardBase_

---

### 5. **ChunkLinearReward Contract** (`contracts/reward/ChunkLinearReward.sol`)

#### **Constructor Parameters**

| Parameter         | Type   | Description                                    | Changeable |
| ----------------- | ------ | ---------------------------------------------- | ---------- |
| `releaseSeconds_` | `uint` | Linear release duration in seconds (immutable) | No         |

_Inherits all parameters from ChunkRewardBase_

---

### 6. **OnePoolReward Contract** (`contracts/reward/OnePoolReward.sol`)

#### **Constructor Parameters**

| Parameter          | Type   | Description                                     | Changeable |
| ------------------ | ------ | ----------------------------------------------- | ---------- |
| `lifetimeSeconds_` | `uint` | Lifetime for reward pool in seconds (immutable) | No         |

#### **Initialization Parameters**

| Parameter | Type      | Description             | Changeable |
| --------- | --------- | ----------------------- | ---------- |
| `market_` | `address` | Market contract address | No         |
| `mine_`   | `address` | Mine contract address   | No         |

---

### 7. **DigestHistory Contract** (`contracts/utils/DigestHistory.sol`)

#### **Constructor Parameters**

| Parameter  | Type   | Description                                    | Changeable |
| ---------- | ------ | ---------------------------------------------- | ---------- |
| `capacity` | `uint` | Maximum number of digests to store (immutable) | No         |
