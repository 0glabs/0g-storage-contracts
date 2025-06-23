// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RewardDistributorSetup
 * @dev Merkle Tree based reward distribution contract. The operator can update the Merkle root daily (off-chain computed),
 *      and users can claim their rewards by providing a valid Merkle proof. Claimed amounts are tracked to prevent double-claiming.
 *      Supports both single claim and batch claim for gas optimization.
 */
contract RewardDistributorSetup is Ownable {
    using MerkleProof for bytes32[];

    // The ERC20 token used for rewards
    IERC20 public immutable rewardToken;

    // The operator who can update the Merkle root
    address public operator;

    // The latest Merkle root representing user rewards
    bytes32 public merkleRoot;
    uint256 public lastUpdateTimestamp;

    // Mapping to track how much each user has claimed
    mapping(address => uint256) public claimed;

    // Batch claim data structure
    struct BatchClaimData {
        uint256 totalReward;
        bytes32[] proof;
    }

    // Event emitted when the Merkle root is updated
    event MerkleRootUpdated(bytes32 newRoot, uint256 timestamp);

    // Event emitted when a user claims rewards
    event RewardClaimed(address indexed user, uint256 amount, uint256 timestamp);

    // Event emitted when a user batch claims rewards
    event BatchRewardClaimed(address indexed user, uint256 totalAmount, uint256 timestamp);

    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    constructor(address _rewardToken, address _operator) {
        require(_rewardToken != address(0), "Invalid token");
        require(_operator != address(0), "Invalid operator");
        rewardToken = IERC20(_rewardToken);
        operator = _operator;
    }

    /**
     * @dev Update the Merkle root. Only the operator can call this. Typically called once per day.
     * @param _merkleRoot The new Merkle root.
     */
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOperator {
        require(_merkleRoot != bytes32(0), "Invalid root");
        merkleRoot = _merkleRoot;
        lastUpdateTimestamp = block.timestamp;
        emit MerkleRootUpdated(_merkleRoot, block.timestamp);
    }

    /**
     * @dev Claim rewards for the user. The user must provide a valid Merkle proof.
     * @param totalReward The total reward allocated to the user (from the off-chain calculation).
     * @param proof The Merkle proof.
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
     * @dev Batch claim rewards for multiple reward periods. This allows users to claim all their historical rewards
     *      in a single transaction, significantly reducing gas costs.
     * @param batchClaims Array of batch claim data containing totalReward and proof for each period.
     */
    function batchClaim(BatchClaimData[] calldata batchClaims) external {
        require(merkleRoot != bytes32(0), "No rewards available");
        require(batchClaims.length > 0, "Empty batch claims");
        require(batchClaims.length <= 20, "Too many claims in batch"); // Prevent gas limit issues

        uint256 totalClaimable = 0;
        uint256 currentClaimed = claimed[msg.sender];

        // Process all claims in the batch
        for (uint256 i = 0; i < batchClaims.length; i++) {
            BatchClaimData calldata claimData = batchClaims[i];
            require(claimData.totalReward > 0, "Invalid reward amount");

            // Verify the Merkle proof for this claim
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender, claimData.totalReward));
            require(claimData.proof.verify(merkleRoot, leaf), "Invalid proof");

            // Add this period's reward to total claimable
            totalClaimable += claimData.totalReward;
        }

        require(totalClaimable > 0, "Nothing to claim");

        // Update claimed amount by adding all claimed rewards
        claimed[msg.sender] = currentClaimed + totalClaimable;

        // Transfer all claimable rewards
        require(rewardToken.transfer(msg.sender, totalClaimable), "Transfer failed");
        emit BatchRewardClaimed(msg.sender, totalClaimable, block.timestamp);
    }

    /**
     * @dev Set a new operator. Only the owner can call this.
     * @param _operator The new operator address.
     */
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Invalid operator");
        operator = _operator;
    }

    /**
     * @dev Emergency withdraw tokens. Only the owner can call this.
     * @param to The recipient address.
     * @param amount The amount to withdraw.
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(rewardToken.transfer(to, amount), "Withdraw failed");
    }
} 