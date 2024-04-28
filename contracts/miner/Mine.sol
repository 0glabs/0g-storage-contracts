// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../utils/IDigestHistory.sol";
import "../utils/DigestHistory.sol";
import "../utils/BitMask.sol";
import "../utils/ZgsSpec.sol";
import "../utils/Blake2b.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IFlow.sol";
import "../interfaces/AddressBook.sol";

import "./RecallRange.sol";
import "./MineLib.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

contract PoraMine {
    using RecallRangeLib for RecallRange;

    bytes32 private constant EMPTY_HASH =
        hex"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";

    uint256 private constant DIFFICULTY_ADJUST_RATIO = 20;
    uint256 private constant TARGET_MINE_BLOCK = 100;

    // Settings bit
    uint256 private constant NO_DATA_SEAL = 0x1;
    uint256 private constant NO_DATA_PROOF = 0x2;
    uint256 private constant FIXED_QUALITY = 0x4;

    // Options for ZeroGStorage-mine development
    bool public immutable sealDataEnabled;
    bool public immutable dataProofEnabled;
    bool public immutable fixedQuality;

    uint256 public adjustRatio;

    AddressBook public immutable book;

    uint256 public lastMinedEpoch = 0;
    uint256 public targetQuality;
    mapping(bytes32 => address) public beneficiaries;

    event NewMinerId(bytes32 indexed minerId, address indexed beneficiary);
    event UpdateMinerId(
        bytes32 indexed minerId,
        address indexed from,
        address indexed to
    );

    constructor(
        address book_,
        uint256 initRate,
        uint256 adjustRatio_,
        uint256 settings
    ) {
        targetQuality = type(uint256).max / initRate / 300;
        adjustRatio = adjustRatio_;
        sealDataEnabled = (settings & NO_DATA_SEAL == 0);
        dataProofEnabled = (settings & NO_DATA_PROOF == 0);
        fixedQuality = (settings & FIXED_QUALITY != 0);
        if (fixedQuality) {
            targetQuality = type(uint256).max;
        }

        book = AddressBook(book_);
    }

    struct PoraAnswer {
        bytes32 contextDigest;
        bytes32 nonce;
        bytes32 minerId;
        RecallRange range;
        uint256 recallPosition;
        uint256 sealOffset;
        bytes32 sealedContextDigest;
        bytes32[UNITS_PER_SEAL] sealedData;
        bytes32[] merkleProof;
    }

    function submit(PoraAnswer memory answer) public {
        // Step 1: check miner ID
        require(answer.minerId != bytes32(0), "MinerId cannot be zero");
        address beneficiary = beneficiaries[answer.minerId];
        require(beneficiary != address(0), "MinerId does not registered");

        MineContext memory context = book.flow().makeContextWithResult();

        // Step 2: basic check for submission
        basicCheck(answer, context);

        // Step 3: check merkle root
        bytes32[UNITS_PER_SEAL] memory unsealedData;
        if (sealDataEnabled) {
            unsealedData = unseal(answer);
        } else {
            unsealedData = answer.sealedData;
        }
        if (dataProofEnabled) {
            bytes32 flowRoot = recoverMerkleRoot(answer, unsealedData);
            require(flowRoot == context.flowRoot, "Inconsistent merkle root");
        }
        delete unsealedData;

        // Step 4: compute PoRA quality
        bytes32 quality = pora(answer);
        require(
            uint256(quality) <= targetQuality,
            "Do not reach target quality"
        );

        // Step 5: adjust quality
        if (!fixedQuality) {
            _adjustQuality(context);
        }

        // Step 6: reward fee
        book.reward().claimMineReward(
            answer.recallPosition / SECTORS_PER_PRICE,
            payable(beneficiary),
            answer.minerId
        );

        // Step 7: finish
        lastMinedEpoch = context.epoch;
    }

    function basicCheck(PoraAnswer memory answer, MineContext memory context)
        public
        view
    {
        // Check basic field
        require(
            context.digest == answer.contextDigest,
            "Inconsistent mining digest"
        );
        require(context.digest != EMPTY_HASH, "Empty digest can not mine");
        require(context.epoch > lastMinedEpoch, "Epoch has been mined");

        // Check validity of recall range
        uint256 maxLength = (context.flowLength / SECTORS_PER_LOAD) *
            SECTORS_PER_LOAD;
        answer.range.check(maxLength);

        // Check the sealing context is in the correct range.
        EpochRange memory epochRange = book.flow().getEpochRange(
            answer.sealedContextDigest
        );
        uint256 recallEndPosition = answer.recallPosition + SECTORS_PER_SEAL;
        require(
            epochRange.start < recallEndPosition &&
                epochRange.end >= recallEndPosition,
            "Invalid sealed context digest"
        );
    }

    function pora(PoraAnswer memory answer) public view returns (bytes32) {
        require(answer.minerId != bytes32(0x0), "Miner ID cannot be empty");

        bytes32[4] memory seedInput = [
            answer.minerId,
            answer.nonce,
            answer.contextDigest,
            answer.range.digest()
        ];

        bytes32[2] memory padSeed = Blake2b.blake2b(seedInput);

        uint256 scratchPadOffset = answer.sealOffset % SEALS_PER_PAD;
        bytes32[UNITS_PER_SEAL] memory mixedData;
        bytes32[2] memory padDigest;
        (padDigest, mixedData) = MineLib.computeScratchPadAndMix(
            answer.sealedData,
            scratchPadOffset,
            padSeed
        );

        require(
            answer.recallPosition ==
                answer.range.recallChunk(keccak256(abi.encode(padDigest))) +
                    answer.sealOffset *
                    SECTORS_PER_SEAL,
            "Incorrect recall position"
        );

        return MineLib.computePoraHash(answer.sealOffset, padSeed, mixedData);
    }

    function unseal(PoraAnswer memory answer)
        public
        pure
        returns (bytes32[UNITS_PER_SEAL] memory unsealedData)
    {
        unsealedData[0] =
            answer.sealedData[0] ^
            keccak256(
                abi.encode(
                    answer.minerId,
                    answer.sealedContextDigest,
                    answer.recallPosition
                )
            );
        for (uint256 i = 1; i < UNITS_PER_SEAL; i += 1) {
            unsealedData[i] =
                answer.sealedData[i] ^
                keccak256(abi.encode(answer.sealedData[i - 1]));
        }
    }

    function recoverMerkleRoot(
        PoraAnswer memory answer,
        bytes32[UNITS_PER_SEAL] memory unsealedData
    ) public pure returns (bytes32) {
        // console.log("Compute leaf");
        // Compute leaf of hash
        for (uint256 i = 0; i < UNITS_PER_SEAL; i += UNITS_PER_SECTOR) {
            bytes32 x;
            assembly {
                x := keccak256(
                    add(unsealedData, mul(i, 32)),
                    256 /*BYTES_PER_SECTOR*/
                )
            }
            unsealedData[i] = x;
            // console.logBytes32(x);
        }

        for (uint256 i = UNITS_PER_SECTOR; i < UNITS_PER_SEAL; i <<= 1) {
            // console.log("i=%d", i);
            for (uint256 j = 0; j < UNITS_PER_SEAL; j += i << 1) {
                bytes32 left = unsealedData[j];
                bytes32 right = unsealedData[j + i];
                unsealedData[j] = keccak256(abi.encode(left, right));
                // console.logBytes32(unsealedData[j]);
            }
        }
        bytes32 currentHash = unsealedData[0];
        delete unsealedData;

        // console.log("Seal root");
        // console.logBytes32(currentHash);

        uint256 unsealedIndex = answer.recallPosition / SECTORS_PER_SEAL;

        for (uint256 i = 0; i < answer.merkleProof.length; i += 1) {
            bytes32 left;
            bytes32 right;
            if (unsealedIndex % 2 == 0) {
                left = currentHash;
                right = answer.merkleProof[i];
            } else {
                left = answer.merkleProof[i];
                right = currentHash;
            }
            currentHash = keccak256(abi.encode(left, right));
            // console.log("sibling");
            // console.logBytes32(answer.merkleProof[i]);
            // console.log("current");
            // console.logBytes32(currentHash);
            unsealedIndex /= 2;
        }
        return currentHash;
    }

    function requestMinerId(address beneficiary, uint64 seed) public {
        bytes32 minerId = keccak256(
            abi.encodePacked(blockhash(block.number - 1), msg.sender, seed)
        );
        require(beneficiaries[minerId] == address(0), "MinerId has registered");
        beneficiaries[minerId] = beneficiary;
        emit NewMinerId(minerId, beneficiary);
    }

    function transferBeneficial(address to, bytes32 minerId) public {
        require(
            beneficiaries[minerId] == msg.sender,
            "Sender does not own minerId"
        );
        beneficiaries[minerId] = to;
        emit UpdateMinerId(minerId, msg.sender, to);
    }

    function _adjustQuality(MineContext memory context) internal {
        uint256 miningBlocks = block.number - context.mineStart;

        // Remove least significant 16 bits to avoid overflow
        uint256 scaledTarget = targetQuality >> 16;
        uint256 scaledExpected = Math.mulDiv(
            scaledTarget,
            miningBlocks,
            TARGET_MINE_BLOCK
        );

        uint256 n = DIFFICULTY_ADJUST_RATIO;

        uint256 scaledAdjusted = (scaledTarget * (n - 1) + scaledExpected) / n;

        if (scaledAdjusted > scaledTarget * 2) {
            scaledAdjusted = scaledTarget * 2;
        }

        if (scaledAdjusted < scaledTarget / 2) {
            scaledAdjusted = scaledTarget / 2;
        }

        if (scaledAdjusted > type(uint256).max >> 16) {
            scaledAdjusted = type(uint256).max >> 16;
        }

        targetQuality = scaledAdjusted << 16;
    }
}
