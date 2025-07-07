// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RewardDistributorSetup
 * @dev Simplified Merkle Tree based reward distribution contract.
 *      The operator updates the Merkle root (computed off-chain),
 *      and users can claim their rewards by providing a valid Merkle proof.
 *      All amounts are in neurons (1 ZGS = 10^18 neurons)
 *
 *      【Replay Attack Prevention Mechanism】
 *      - Users can only claim incremental rewards (totalReward - previously claimed)
 *      - The contract tracks cumulative claimed amounts through claimed[msg.sender]
 *      - Replayed proofs result in claimable=0, preventing duplicate distribution
 */
contract RewardDistributorSetup is Ownable {
    using MerkleProof for bytes32[];

    // The ERC20 token used for rewards (ZGS token)
    IERC20 public immutable rewardToken;

    // The operator who can update the Merkle root
    address public operator;

    // Current epoch and Merkle root
    uint256 public currentEpoch;
    bytes32 public merkleRoot;
    uint256 public lastUpdateTimestamp;

    // Mapping to track how much each user has claimed (in neurons)
    mapping(address => uint256) public claimed;

    // Event emitted when the Merkle root is updated
    event MerkleRootUpdated(uint256 epoch, bytes32 newRoot, uint256 timestamp);

    // Event emitted when a user claims rewards
    event RewardClaimed(address indexed user, uint256 amount, uint256 timestamp);

    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    constructor(address _rewardToken, address _operator) Ownable(msg.sender) {
        require(_rewardToken != address(0), "Invalid token");
        require(_operator != address(0), "Invalid operator");
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
    }

    /**
     * @dev Update the Merkle root for a new epoch. Only the operator can call this.
     * @param _epoch The epoch number
     * @param _merkleRoot The new Merkle root
     */
    function updateRewards(uint256 _epoch, bytes32 _merkleRoot) external onlyOperator {
        require(_merkleRoot != bytes32(0), "Invalid root");
        require(_epoch > currentEpoch, "Invalid epoch");
        
        currentEpoch = _epoch;
        merkleRoot = _merkleRoot;
        lastUpdateTimestamp = block.timestamp;
        
        emit MerkleRootUpdated(_epoch, _merkleRoot, block.timestamp);
    }

    /**
     * @dev Claim rewards for the user. The user must provide a valid Merkle proof.
     * @param totalReward The total reward allocated to the user in neurons
     * @param proof The Merkle proof
     */
    function claim(uint256 totalReward, bytes32[] calldata proof) external {
        require(merkleRoot != bytes32(0), "No rewards available");
        require(totalReward > 0, "No reward");

        // Verify the user's leaf
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, totalReward));
        require(proof.verify(merkleRoot, leaf), "Invalid proof");

        uint256 alreadyClaimed = claimed[msg.sender];
        require(alreadyClaimed < totalReward, "Already claimed");

        uint256 claimable = totalReward - alreadyClaimed;
        require(claimable > 0, "Nothing to claim");

        claimed[msg.sender] = totalReward;

        require(rewardToken.transfer(msg.sender, claimable), "Transfer failed");
        emit RewardClaimed(msg.sender, claimable, block.timestamp);
    }

    /**
     * @dev Set a new operator. Only the owner can call this.
     * @param _operator The new operator address
     */
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Invalid operator");
        operator = _operator;
    }

    /**
     * @dev Emergency withdraw tokens. Only the owner can call this.
     * @param to The recipient address
     * @param amount The amount to withdraw in neurons
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(rewardToken.transfer(to, amount), "Withdraw failed");
    }
} 