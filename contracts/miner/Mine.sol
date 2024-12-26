// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../utils/DigestHistory.sol";
import "../utils/BitMask.sol";
import "../utils/ZgsSpec.sol";
import "../utils/ZgInitializable.sol";
import "../utils/Blake2b.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IFlow.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IDigestHistory.sol";

import "./RecallRange.sol";
import "./MineLib.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract PoraMine is ZgInitializable, AccessControlEnumerable {
    using RecallRangeLib for RecallRange;

    bytes32 public constant PARAMS_ADMIN_ROLE = keccak256("PARAMS_ADMIN_ROLE");

    // constants
    bytes32 private constant EMPTY_HASH = hex"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";

    // Options for ZeroGStorage-mine development & Setting bits
    bool public immutable sealDataEnabled;
    bool public immutable dataProofEnabled;
    bool public immutable fixedDifficulty;
    uint private constant NO_DATA_SEAL = 0x1;
    uint private constant NO_DATA_PROOF = 0x2;
    uint private constant FIXED_DIFFICULTY = 0x4;

    uint64 private constant PORA_VERSION = 1;

    // Deferred initializd fields
    address public flow;
    address public reward;

    mapping(bytes32 => bool) private _submittedPora;

    // Configurable parameters
    uint public targetMineBlocks;
    uint public targetSubmissions;
    uint public targetSubmissionsNextEpoch;
    uint public difficultyAdjustRatio;
    uint64 public maxShards;

    // Contract state
    uint public lastMinedEpoch;
    uint public currentSubmissions;
    uint public poraTarget;

    mapping(bytes32 => address) public beneficiaries;

    // Updated configurable parameters
    uint public minDifficulty;

    event NewMinerId(bytes32 indexed minerId, address indexed beneficiary);
    event UpdateMinerId(bytes32 indexed minerId, address indexed from, address indexed to);
    event NewSubmission(uint indexed epoch, bytes32 indexed minerId, uint epochIndex, uint recallPosition);

    constructor(uint settings) {
        sealDataEnabled = (settings & NO_DATA_SEAL == 0);
        dataProofEnabled = (settings & NO_DATA_PROOF == 0);
        fixedDifficulty = (settings & FIXED_DIFFICULTY != 0);
    }

    function initialize(uint difficulty, address flow_, address reward_) public onlyInitializeOnce {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PARAMS_ADMIN_ROLE, _msgSender());

        poraTarget = type(uint).max / difficulty;
        if (fixedDifficulty) {
            poraTarget = type(uint).max;
        }
        flow = flow_;
        reward = reward_;
        targetMineBlocks = 100;
        targetSubmissions = 10;
        targetSubmissionsNextEpoch = 10;
        difficultyAdjustRatio = 20;
        maxShards = 32;
    }

    function poraVersion() external pure returns (uint64) {
        return PORA_VERSION;
    }

    function submit(MineLib.PoraAnswer memory answer) public {
        // Step 1: check miner ID
        require(answer.minerId != bytes32(0), "MinerId cannot be zero");
        address beneficiary = beneficiaries[answer.minerId];
        require(beneficiary != address(0), "MinerId does not registered");

        // Step 2: maintain context
        MineContext memory context = IFlow(flow).makeContextWithResult();
        require(context.epoch >= lastMinedEpoch, "Internal error: epoch number decrease");
        if (context.epoch > lastMinedEpoch && lastMinedEpoch > 0) {
            if (currentSubmissions < targetSubmissions) {
                // Not enough submissions in the last epoch
                _adjustDifficultyOnIncompleteEpoch();
            }
            currentSubmissions = 0;
            targetSubmissions = targetSubmissionsNextEpoch;
        }

        // Step 3: basic check for submission
        basicCheck(answer, context);
        require(answer.range.numShards() <= maxShards, "Exceeding the allowed number of shards");

        // Step 4: configurable check
        bytes32[UNITS_PER_SEAL] memory unsealedData;
        if (sealDataEnabled) {
            unsealedData = MineLib.unseal(answer);
        } else {
            unsealedData = answer.sealedData;
        }
        if (dataProofEnabled) {
            bytes32 flowRoot = MineLib.recoverMerkleRoot(answer, unsealedData);
            require(flowRoot == context.flowRoot, "Inconsistent merkle root");
        }
        delete unsealedData;

        // Step 5: compute PoRA hash
        bytes32 poraOutput = pora(answer);
        uint scaleX64 = answer.range.targetScaleX64(context.flowLength);
        // scaleX64 >= 2^64, so there is no overflow
        require(uint(poraOutput) <= (poraTarget / scaleX64) << 64, "Do not reach target quality");
        require(!_submittedPora[poraOutput], "Answer has been submitted");
        _submittedPora[poraOutput] = true;

        // Step 6: reward
        IReward(reward).claimMineReward(
            answer.recallPosition / SECTORS_PER_PRICE,
            payable(beneficiary),
            answer.minerId
        );

        // Step 7: bump submission
        emit NewSubmission(context.epoch, answer.minerId, currentSubmissions, answer.recallPosition);
        lastMinedEpoch = context.epoch;
        currentSubmissions += 1;
        if (currentSubmissions < targetSubmissions) {
            return;
        }

        // Step 8: adjust quality
        if (!fixedDifficulty) {
            _adjustDifficulty(context);
        }
    }

    function basicCheck(MineLib.PoraAnswer memory answer, MineContext memory context) public view {
        // Check basic field
        require(context.digest == answer.contextDigest, "Inconsistent mining digest");
        require(context.digest != EMPTY_HASH, "Empty digest can not mine");
        require(currentSubmissions < targetSubmissions, "Epoch has enough submissions");

        // Check validity of recall range
        uint maxLength = (context.flowLength / SECTORS_PER_LOAD) * SECTORS_PER_LOAD;
        answer.range.check(maxLength);

        // Check the sealing context is in the correct range.
        EpochRange memory epochRange = IFlow(flow).getEpochRange(answer.sealedContextDigest);
        uint recallEndPosition = answer.recallPosition + SECTORS_PER_SEAL;
        require(
            epochRange.start < recallEndPosition && epochRange.end >= recallEndPosition,
            "Invalid sealed context digest"
        );
    }

    function pora(MineLib.PoraAnswer memory answer) public view returns (bytes32) {
        require(answer.minerId != bytes32(0x0), "Miner ID cannot be empty");

        bytes32[4] memory seedInput = [answer.minerId, answer.nonce, answer.contextDigest, answer.range.digest()];

        bytes32[2] memory padSeed = Blake2b.blake2b(seedInput);

        uint scratchPadOffset = answer.sealOffset % SEALS_PER_PAD;
        bytes32[UNITS_PER_SEAL] memory mixedData;
        bytes32[2] memory padDigest;
        (padDigest, mixedData) = MineLib.computeScratchPadAndMix(answer.sealedData, scratchPadOffset, padSeed);

        require(
            answer.recallPosition ==
                answer.range.recallChunk(keccak256(abi.encode(padDigest))) + answer.sealOffset * SECTORS_PER_SEAL,
            "Incorrect recall position"
        );

        return MineLib.computePoraHash(answer.sealOffset, padSeed, mixedData);
    }

    function requestMinerId(address beneficiary, uint64 seed) public {
        bytes32 minerId = keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender, seed));
        require(beneficiaries[minerId] == address(0), "MinerId has registered");
        beneficiaries[minerId] = beneficiary;
        emit NewMinerId(minerId, beneficiary);
    }

    function transferBeneficial(address to, bytes32 minerId) public {
        require(beneficiaries[minerId] == msg.sender, "Sender does not own minerId");
        beneficiaries[minerId] = to;
        emit UpdateMinerId(minerId, msg.sender, to);
    }

    function _adjustDifficulty(MineContext memory context) internal {
        uint miningBlocks = block.number - context.mineStart;

        // Remove least significant 16 bits to avoid overflow
        uint scaledTarget = poraTarget >> 16;
        uint scaledExpected = Math.mulDiv(scaledTarget, miningBlocks, targetMineBlocks);

        _adjustDifficultyInner(scaledExpected);
    }

    function _adjustDifficultyOnIncompleteEpoch() internal {
        _adjustDifficultyInner(type(uint).max >> 16);
    }

    function _adjustDifficultyInner(uint scaledExpected) internal {
        uint scaledTarget = poraTarget >> 16;

        uint n = difficultyAdjustRatio;

        uint scaledAdjusted = (scaledTarget * (n - 1) + scaledExpected) / n;

        if (scaledAdjusted > scaledTarget * 2) {
            scaledAdjusted = scaledTarget * 2;
        }

        if (scaledAdjusted < scaledTarget / 2) {
            scaledAdjusted = scaledTarget / 2;
        }

        if (scaledAdjusted > type(uint).max >> 16) {
            scaledAdjusted = type(uint).max >> 16;
        }

        poraTarget = scaledAdjusted << 16;

        uint maxPoraTarget = _maxPoraTarget();
        if (poraTarget > maxPoraTarget) {
            poraTarget = maxPoraTarget;
        }
    }

    function _maxPoraTarget() internal view returns (uint) {
        if (minDifficulty == 0) {
            return type(uint).max;
        } else {
            return type(uint).max / minDifficulty;
        }
    }

    function setTargetMineBlocks(uint targetMineBlocks_) external onlyRole(PARAMS_ADMIN_ROLE) {
        targetMineBlocks = targetMineBlocks_;
    }

    function setTargetSubmissions(uint targetSubmissions_) external onlyRole(PARAMS_ADMIN_ROLE) {
        targetSubmissionsNextEpoch = targetSubmissions_;
        if (lastMinedEpoch == 0) {
            targetSubmissions = targetSubmissions_;
        }
    }

    function setDifficultyAdjustRatio(uint difficultyAdjustRatio_) external onlyRole(PARAMS_ADMIN_ROLE) {
        require(difficultyAdjustRatio_ > 0, "Adjust ratio must be non-zero");
        difficultyAdjustRatio = difficultyAdjustRatio_;
    }

    function setMaxShards(uint64 maxShards_) external onlyRole(PARAMS_ADMIN_ROLE) {
        require(maxShards_ > 0, "Max shard number cannot be zero");
        require(maxShards_ & (maxShards_ - 1) == 0, "Max shard number must be power of 2");
        maxShards = maxShards_;
    }

    function setMinDifficulty(uint minDifficulty_) external onlyRole(PARAMS_ADMIN_ROLE) {
        minDifficulty = minDifficulty_;
        uint maxPoraTarget = _maxPoraTarget();
        if (poraTarget > maxPoraTarget) {
            poraTarget = maxPoraTarget;
        }
    }

    function canSubmit() external returns (bool) {
        MineContext memory context = IFlow(flow).makeContextWithResult();
        return context.epoch > lastMinedEpoch || currentSubmissions < targetSubmissions;
    }
}
