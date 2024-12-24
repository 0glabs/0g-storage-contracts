// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/Blake2b.sol";
import "../utils/DeepCopy.sol";
import "./RecallRange.sol";

library MineLib {
    using DeepCopy for bytes32[2];

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

    function scratchPadHash(bytes32[2] memory padDigest, uint rounds) internal pure {
        assembly {
            for {
                let i := 0
            } lt(i, rounds) {
                i := add(i, 1)
            } {
                mstore(padDigest, keccak256(padDigest, 0x40))
                mstore(add(padDigest, 0x20), keccak256(padDigest, 0x40))
            }
        }
    }

    function scratchPadHashOnce(bytes32[2] memory padDigest) internal pure {
        assembly {
            mstore(padDigest, keccak256(padDigest, 0x40))
            mstore(add(padDigest, 0x20), keccak256(padDigest, 0x40))
        }
    }

    function computeScratchPadAndMix(
        bytes32[UNITS_PER_SEAL] memory sealedData,
        uint skipSeals,
        bytes32[2] memory padDigest
    ) internal view returns (bytes32[2] memory recallSeed, bytes32[UNITS_PER_SEAL] memory mixedData) {
        bytes32[2] memory currentDigest = padDigest.deepCopy();

        scratchPadHash(currentDigest, skipSeals * BHASHES_PER_SEAL);
        unchecked {
            for (uint i = 0; i < UNITS_PER_SEAL; i += 2) {
                scratchPadHashOnce(currentDigest);

                mixedData[i] = currentDigest[0] ^ sealedData[i];
                mixedData[i + 1] = currentDigest[1] ^ sealedData[i + 1];
            }
        }
        scratchPadHash(currentDigest, (SEALS_PER_PAD - skipSeals - 1) * BHASHES_PER_SEAL);

        recallSeed = currentDigest.deepCopy();
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

        // Update the blake2b hasher with the input `mixedData` and compute the blake2b hash.
        //
        // EVM is optimized for 32-byte aligned memory accesses, but the bultin contract
        // blake2b's parameters aren't always aligned. We allocate memory to align most parameters to
        // 32 bytes and use assembly to set up the blake2b parameters.
        // The memory space for parameters is reused across calls to save gas.
        bytes32[8] memory slots;
        uint offset = 128;
        uint finalizeOffset = 128 + UNITS_PER_SEAL * 32;

        assembly {
            let argPtr := add(slots, 0x1c)
            let roundPtr := add(slots, 0x1f)
            let hPtr := add(slots, 0x20)
            let mPtr := add(slots, 0x60)
            let offsetLo := add(slots, 0xe0)
            let offsetHi := add(slots, 0xe1)
            let finalizePtr := add(slots, 0xf0)

            let dataPtr := mixedData

            mstore8(roundPtr, 12)

            mstore(hPtr, mload(h))
            mstore(add(hPtr, 0x20), mload(add(h, 0x20)))

            for {

            } lt(offset, finalizeOffset) {

            } {
                offset := add(offset, 0x80)
                mstore8(offsetLo, and(offset, 0xff))
                mstore8(offsetHi, shr(8, offset))

                mstore(mPtr, mload(dataPtr))
                mstore(add(mPtr, 0x20), mload(add(dataPtr, 0x20)))
                mstore(add(mPtr, 0x40), mload(add(dataPtr, 0x40)))
                mstore(add(mPtr, 0x60), mload(add(dataPtr, 0x60)))
                dataPtr := add(dataPtr, 128)

                if eq(offset, finalizeOffset) {
                    mstore8(finalizePtr, 1)
                }

                if iszero(staticcall(not(0), 0x09, argPtr, 0xd5, hPtr, 0x40)) {
                    revert(0, 0)
                }
            }
        }
        // The blake2b hash locates at slots[1] and slots[2].
        // Here we only return the first 32 bytes of the blake2b hash.
        return slots[1];
    }

    function unseal(PoraAnswer memory answer) internal pure returns (bytes32[UNITS_PER_SEAL] memory unsealedData) {
        unsealedData[0] =
            answer.sealedData[0] ^
            keccak256(abi.encode(answer.minerId, answer.sealedContextDigest, answer.recallPosition));
        bytes32[UNITS_PER_SEAL] memory sealedData = answer.sealedData;

        // Equivalent to
        // unsealedData[i] = answer.sealedData[i] ^ keccak256(abi.encode(answer.sealedData[i - 1]));
        uint length = UNITS_PER_SEAL;
        assembly {
            let sealedPtr := sealedData
            let unsealedPtr := unsealedData

            let lastUnsealedPtr := add(unsealedPtr, mul(sub(length, 1), 0x20))

            for {

            } lt(unsealedPtr, lastUnsealedPtr) {

            } {
                let mask := keccak256(sealedPtr, 0x20)

                sealedPtr := add(sealedPtr, 0x20)
                let data := mload(sealedPtr)

                unsealedPtr := add(unsealedPtr, 0x20)
                mstore(unsealedPtr, xor(data, mask))
            }
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
