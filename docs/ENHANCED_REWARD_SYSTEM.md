# ZGS Reward Distribution System

## Overview

This is a ZGS token reward distribution system based on Merkle Tree, adopting an off-chain calculation + on-chain verification architecture. The system prevents replay attacks through Merkle proofs and supports efficient batch ZGS reward distribution.

## Core Features

### 🛡️ Replay Attack Prevention
- Based on `totalReward - claimed` difference calculation
- Even if proof is replayed, duplicate claims are impossible
- Merkle Tree verification ensures data integrity

### ⚡ Efficient Distribution
- Off-chain Merkle Tree construction, on-chain verification
- Supports batch claims, saving gas fees
- Incremental updates, avoiding duplicate calculations

### 🔄 Flexible Updates
- Daily Merkle root updates
- Supports users claiming latest ZGS rewards anytime
- Simple on-chain/off-chain collaboration

## System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Off-chain     │───▶│  Merkle Tree    │───▶│ Smart Contract  │
│   Service       │    │  Generation     │    │ (Distribution)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Data     │    │  Merkle Root    │    │   User Claims   │
│   & Rewards     │    │  & Proofs       │    │   & ZGS Rewards │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Contract Functions

### Main Functions

#### `updateMerkleRoot(bytes32 _merkleRoot)`
- **Permission**: Operator only
- **Function**: Update Merkle root (called daily at 00:00)
- **Parameter**: `_merkleRoot` - New Merkle root

#### `claim(uint256 totalReward, bytes32[] calldata proof)`
- **Permission**: Any user
- **Function**: Claim ZGS rewards
- **Parameters**: 
  - `totalReward`: User's total ZGS reward amount
  - `proof`: Merkle proof

#### `batchClaim(BatchClaimData[] calldata batchClaims)`
- **Permission**: Any user
- **Function**: Batch claim ZGS rewards
- **Parameter**: Batch claim data array

#### `getClaimableAmount(address user, uint256 totalReward, bytes32[] calldata proof)`
- **Permission**: Anyone
- **Function**: Query user's claimable ZGS amount
- **Return**: Claimable ZGS reward amount

## Usage

### 1. Deploy Contract

```bash
# Set ZGS token address environment variable
export ZGS_TOKEN_ADDRESS="0x1234567890123456789012345678901234567890"

# Deploy ZGS reward distribution contract
npx hardhat run scripts/deploy-enhanced-reward-distributor.ts --network <network>
```

### 2. Configure Off-chain Service

```typescript
// Your server-side implementation
class ZGSRewardService {
    // Update daily at 00:00
    async updateDailyRewards(): Promise<void> {
        // 1. Calculate all users' latest totalReward
        const userRewards = await this.calculateUserRewards();
        
        // 2. Build Merkle Tree
        const merkleTree = this.buildMerkleTree(userRewards);
        
        // 3. Update on-chain root
        await this.updateMerkleRootOnChain(merkleTree.getRoot());
    }
    
    // Generate proof for user
    async getUserProof(userAddress: string): Promise<{totalReward: number, proof: string[]}> {
        const userReward = await this.getUserReward(userAddress);
        const proof = this.generateProof(userAddress, userReward);
        return { totalReward: userReward, proof };
    }
}
```

### 3. User Claims ZGS Rewards

```typescript
// User gets proof from your service
const { totalReward, proof } = await zgsRewardService.getUserProof(userAddress);

// User calls contract to claim ZGS
await rewardDistributor.claim(totalReward, proof);
```

## Workflow

### Daily Reward Update Process

1. **Calculate User ZGS Rewards**
   ```typescript
   const userRewards = [
       { user: "0x123...", totalReward: 1000 }, // 1000 ZGS
       { user: "0x456...", totalReward: 2000 }  // 2000 ZGS
   ];
   ```

2. **Build Merkle Tree**
   ```typescript
   const merkleTree = buildMerkleTree(userRewards);
   const root = merkleTree.getRoot();
   ```

3. **Update On-chain Root**
   ```typescript
   await contract.updateMerkleRoot(root);
   ```

### User Claim Process

1. **Get Proof**
   ```typescript
   const { totalReward, proof } = await service.getUserProof(userAddress);
   ```

2. **Verify Claimable Amount**
   ```typescript
   const claimable = await contract.getClaimableAmount(userAddress, totalReward, proof);
   ```

3. **Claim ZGS Rewards**
   ```typescript
   await contract.claim(totalReward, proof);
   ```

## Replay Attack Prevention

### Core Principle

```solidity
// On-chain record of user's cumulative claimed amount
mapping(address => uint256) public claimedAmounts;

// Calculate difference on each claim
uint256 alreadyClaimed = claimedAmounts[msg.sender];
uint256 claimable = totalReward - alreadyClaimed;

// Update claimed amount
claimedAmounts[msg.sender] = totalReward;
```

### Replay Attack Protection

1. **Proof Replay Invalid**: Even if the same proof is resubmitted, `claimedAmounts` already equals `totalReward`, difference is 0
2. **Merkle Verification**: Ensures proof corresponds to correct `totalReward`
3. **Incremental Updates**: Each time root is updated, users can only claim the newly added ZGS reward portion

## Testing

Run test script to verify functionality:

```bash
# Set ZGS token address
export ZGS_TOKEN_ADDRESS="0x1234567890123456789012345678901234567890"

# Run tests
npx hardhat run scripts/test-enhanced-reward-distributor.ts --network localhost
```

## Configuration

### Environment Variables

```bash
ZGS_TOKEN_ADDRESS="0x..."              # ZGS token address (required)
CONTRACT_ADDRESS="0x..."               # Contract address
OPERATOR_ADDRESS="0x..."               # Operator address
OPERATOR_PRIVATE_KEY="0x..."           # Operator private key
```

### ZGS Token Requirements

- Must be a valid ZGS token contract (implements ISafeERC20 interface)
- Deployer account must have sufficient ZGS token balance for testing
- ZGS token contract must implement standard ERC20 interface

## Security Considerations

### Replay Attack Prevention
- Based on `totalReward - claimed` difference calculation
- Merkle proof verification
- Users can only claim their own ZGS rewards

### Permission Control
- Operator permission management (update root)
- Users can only claim their own ZGS rewards
- Emergency withdrawal functionality

### Gas Optimization
- Batch processing reduces transaction count
- Efficient Merkle verification
- Incremental updates avoid duplicate calculations

## On-chain/Off-chain Division of Labor

### Off-chain Services (Our Responsibility)
- **Data Statistics**: Calculate user ZGS rewards
- **Merkle Tree Construction**: Generate root and proof
- **Root Updates**: Regularly update on-chain root
- **Proof Service**: Provide proof queries for users

### On-chain Contract
- **Root Storage**: Store current Merkle root
- **Proof Verification**: Verify user-submitted proofs
- **Replay Prevention**: Record user's claimed ZGS amount
- **ZGS Distribution**: Automatically transfer ZGS to users

## Troubleshooting

### Common Issues

1. **"Invalid proof" Error**
   - Check if Merkle tree generation is correct
   - Verify if root has been updated

2. **"Already claimed" Error**
   - Check if user has already claimed
   - Verify if totalReward is correct

3. **"Not operator" Error**
   - Confirm if caller is authorized Operator

### Debug Tools

```typescript
// Get contract status
const root = await rewardDistributor.currentMerkleRoot();
const claimed = await rewardDistributor.claimedAmounts(userAddress);

// Check user status
console.log('Merkle root:', root);
console.log('User claimed ZGS:', claimed);
```

## Contributing

Welcome to submit Issues and Pull Requests to improve this system.

## License

Unlicense 