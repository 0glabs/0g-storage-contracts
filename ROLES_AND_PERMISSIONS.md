# Roles and Money Control Permissions Documentation

This document outlines all key roles, permissions, and financial control mechanisms across the 0G Storage smart contracts.

## Overview

The 0G Storage system consists of several interconnected contracts that handle data storage, mining rewards, token economics, and fee management. Financial controls are distributed across multiple contracts with different role-based access patterns.

---

## Key Roles by Contract

### 1. **PoraMine Contract** (`contracts/miner/Mine.sol`)

| Role                 | Contract | Permissions                               | Can Control Money? | Functions                                                                                                                       |
| -------------------- | -------- | ----------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE` | PoraMine | Full admin privileges, grant/revoke roles | Indirect           | All admin functions                                                                                                             |
| `PARAMS_ADMIN_ROLE`  | PoraMine | Mining parameter configuration            | No                 | `setTargetMineBlocks`, `setTargetSubmissions`, `setDifficultyAdjustRatio`, `setMaxShards`, `setMinDifficulty`, `setNumSubtasks` |
| Miner/Beneficiary    | PoraMine | Receive mining rewards                    | Yes (receive only) | Rewards distributed via `submit()`                                                                                              |

**Financial Impact**: No direct money withdrawal, but controls mining reward distribution through the reward contract.

---

### 2. **ChunkRewardBase Contract** (`contracts/reward/ChunkRewardBase.sol`)

| Role                 | Contract        | Permissions                 | Can Control Money? | Functions                                           |
| -------------------- | --------------- | --------------------------- | ------------------ | --------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE` | ChunkRewardBase | Full admin privileges       | Indirect           | Grant/revoke roles                                  |
| `PARAMS_ADMIN_ROLE`  | ChunkRewardBase | Configure reward parameters | Yes (indirect)     | `setBaseReward`, `setServiceFeeRate`, `setTreasury` |
| `market` address     | ChunkRewardBase | Deposit rewards             | Yes                | `fillReward`                                        |
| `mine` address       | ChunkRewardBase | Distribute mining rewards   | Yes                | `claimMineReward`                                   |
| `treasury` address   | ChunkRewardBase | Receive service fees        | Yes (receive)      | Automatically receives service fees                 |
| Anyone               | ChunkRewardBase | Donate to base reward pool  | Yes                | `donate`                                            |

**Financial Controls**:

-   Service fee collection (configurable rate)
-   Mining reward distribution
-   Treasury fee management
-   Base reward pool funding

---

### 3. **Flow Contract** (`contracts/dataFlow/Flow.sol`)

| Role                 | Contract | Permissions            | Can Control Money? | Functions                 |
| -------------------- | -------- | ---------------------- | ------------------ | ------------------------- |
| `DEFAULT_ADMIN_ROLE` | Flow     | Full admin privileges  | Indirect           | Administrative functions  |
| `PAUSER_ROLE`        | Flow     | Pause/unpause contract | No                 | `pause`, `unpause`        |
| `market` address     | Flow     | Data flow management   | No                 | Data submission functions |

**Financial Impact**: Manages data flow but delegates financial operations to Reward contracts.

---

### 4. **StakeToken Contract** (`contracts/token/StakeToken.sol`)

| Role  | Contract   | Permissions              | Can Control Money? | Functions          |
| ----- | ---------- | ------------------------ | ------------------ | ------------------ |
| Users | StakeToken | Stake/unstake ZGS tokens | Yes                | `stake`, `unstake` |

**Financial Controls**:

-   ZGS token staking
-   Proportional unstaking
-   No admin withdrawal functions

---

## Summary of Money Control Permissions

### **Direct Withdrawal/Transfer Capabilities**

| Entity        | Contract        | Method             | Description                            |
| ------------- | --------------- | ------------------ | -------------------------------------- |
| Treasury      | ChunkRewardBase | Automatic transfer | Receives service fees                  |
| Stake address | PeakSwap        | Token transfers    | Receives swap proceeds                 |
| Miners        | ChunkRewardBase | `_asyncTransfer()` | Mining reward distribution             |
| Users         | StakeToken      | `transfer()`       | Stake/unstake operations               |
| Anyone        | PeakSwap        | `skim()`           | Withdraw excess tokens beyond reserves |

### **Administrative Control Over Funds**

| Role                | Contract        | Control Type         | Impact                                          |
| ------------------- | --------------- | -------------------- | ----------------------------------------------- |
| `PARAMS_ADMIN_ROLE` | ChunkRewardBase | Set treasury address | Controls where service fees go                  |
| `PARAMS_ADMIN_ROLE` | ChunkRewardBase | Set service fee rate | Controls fee percentage                         |
| `PARAMS_ADMIN_ROLE` | ChunkRewardBase | Set base reward      | Controls additional mining rewards              |
| Contract deployer   | All contracts   | Initial setup        | Sets critical addresses (stake, treasury, etc.) |

### **No Direct Admin Withdrawal**

The following contracts **do not** have administrative withdrawal functions:

-   **PoraMine**: No admin can withdraw funds
-   **Flow**: No financial functions
-   **UploadToken**: No admin withdrawal capabilities
-   **StakeToken**: No admin withdrawal, only user stake/unstake

---

## Security Considerations

### **Centralization Risks**

1. **Treasury Control**: `PARAMS_ADMIN_ROLE` can change where service fees are sent
2. **Base Reward Control**: Admins can modify mining reward amounts
3. **Contract Pausing**: `PAUSER_ROLE` can halt operations
4. **Parameter Changes**: Various admin roles can modify economic parameters

### **Safeguards**

1. **No Direct Admin Withdrawal**: No role can directly withdraw user funds
2. **Automated Transfers**: Most fund movements are automatic based on protocol rules
3. **Role Separation**: Different aspects controlled by different roles
4. **Time-based Delays**: Some contracts may implement timelock controls

### **User Fund Safety**

-   Mining rewards are distributed through the mining contract, not admin-controlled
-   Staking tokens can be unstaked by users directly
-   No admin can directly access user balances

---

## Deployment Considerations

When deploying, ensure:

1. Treasury addresses are set to appropriate multi-sig wallets
2. Admin roles are granted to governance contracts or multi-sig
3. Stake addresses are properly configured
4. Service fee rates are set to reasonable levels
5. All inter-contract addresses are correctly configured

---

## Parameters

1. blocksPerEpoch: Set epoch time to be 20 min, current block time is 400ms, then blocksPerEpoch = 3000
2. lifetimeMonth: 12 months by default
3. price: $11/TB/month
4. PricePerSector(256 Bytes)/Month: $\text{lifetimeMonth} * \text{unitPrice} * 256 * 1,000,000,000,000,000,000 / 1024 / 1024 / 1024 / 12$.
5. unitPrice: $\text{unitPrice} = \$11 / \text{pricePerToken} / 1024$
