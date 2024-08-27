// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/Blake2b.sol";
import "./RecallRange.sol";

library MineLib {
    struct PoraAnswer {
        bytes32 contextDigest;
        bytes32 nonce;
        bytes32 minerId;
        RecallRange range;
        uint recallPosition;
        uint sealOffset;
        bytes32 sealedContextDigest;
        bytes32[UNITS_PER_SEAL] sealedData;
        bytes32[] merkleProof;
    }

    function computeScratchPadAndMix(
        bytes32[UNITS_PER_SEAL] memory sealedData,
        uint skipSeals,
        bytes32[2] memory padDigest
    ) internal view returns (bytes32[2] memory recallSeed, bytes32[UNITS_PER_SEAL] memory mixedData) {
        for (uint i = 0; i < skipSeals; i += 1) {
            for (uint j = 0; j < BHASHES_PER_SEAL; j += 1) {
                padDigest = Blake2b.blake2b(padDigest);
            }
        }

        for (uint i = 0; i < UNITS_PER_SEAL; i += 2) {
            padDigest = Blake2b.blake2b(padDigest);
            mixedData[i] = padDigest[0] ^ sealedData[i];
            mixedData[i + 1] = padDigest[1] ^ sealedData[i + 1];
        }

        for (uint i = skipSeals + 1; i < SEALS_PER_PAD; i += 1) {
            for (uint j = 0; j < BHASHES_PER_SEAL; j += 1) {
                padDigest = Blake2b.blake2b(padDigest);
            }
        }

        recallSeed = padDigest;
    }

    function computePoraHash(
        uint sealOffset,
        bytes32[2] memory padSeed,
        bytes32[UNITS_PER_SEAL] memory mixedData
    ) internal view returns (bytes32) {
        bytes32[2] memory h;
        h[0] = Blake2b.BLAKE2B_INIT_STATE0;
        h[1] = Blake2b.BLAKE2B_INIT_STATE1;

        h = Blake2b.blake2bF(h, bytes32(sealOffset), padSeed[0], padSeed[1], bytes32(0), 128, false);
        for (uint i = 0; i < UNITS_PER_SEAL - 4; i += 4) {
            uint length;
            unchecked {
                length = 128 + 32 * (i + 4);
            }
            h = Blake2b.blake2bF(h, mixedData[i], mixedData[i + 1], mixedData[i + 2], mixedData[i + 3], length, false);
        }
        h = Blake2b.blake2bF(
            h,
            mixedData[UNITS_PER_SEAL - 4],
            mixedData[UNITS_PER_SEAL - 3],
            mixedData[UNITS_PER_SEAL - 2],
            mixedData[UNITS_PER_SEAL - 1],
            128 + UNITS_PER_SEAL * 32,
            true
        );
        return h[0];
    }

    function unseal(PoraAnswer memory answer) internal pure returns (bytes32[UNITS_PER_SEAL] memory unsealedData) {
        unsealedData[0] =
            answer.sealedData[0] ^
            keccak256(abi.encode(answer.minerId, answer.sealedContextDigest, answer.recallPosition));
        for (uint i = 1; i < UNITS_PER_SEAL; i += 1) {
            unsealedData[i] = answer.sealedData[i] ^ keccak256(abi.encode(answer.sealedData[i - 1]));
        }
    }

    function recoverMerkleRoot(
        PoraAnswer memory answer,
        bytes32[UNITS_PER_SEAL] memory unsealedData
    ) internal pure returns (bytes32) {
        // Compute leaf of hash
        for (uint i = 0; i < UNITS_PER_SEAL; i += UNITS_PER_SECTOR) {
            bytes32 x;
            assembly {
                x := keccak256(add(unsealedData, mul(i, 32)), 256 /*BYTES_PER_SECTOR*/)
            }
            unsealedData[i] = x;
        }

        for (uint i = UNITS_PER_SECTOR; i < UNITS_PER_SEAL; i <<= 1) {
            for (uint j = 0; j < UNITS_PER_SEAL; j += i << 1) {
                bytes32 left = unsealedData[j];
                bytes32 right = unsealedData[j + i];
                unsealedData[j] = keccak256(abi.encode(left, right));
            }
        }
        bytes32 currentHash = unsealedData[0];
        delete unsealedData;

        uint unsealedIndex = answer.recallPosition / SECTORS_PER_SEAL;

        for (uint i = 0; i < answer.merkleProof.length; i += 1) {
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

            unsealedIndex /= 2;
        }
        return currentHash;
    }
}
