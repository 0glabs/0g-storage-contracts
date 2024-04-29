// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/Blake2b.sol";

library MineLib {
    function computeScratchPadAndMix(
        bytes32[UNITS_PER_SEAL] memory sealedData,
        uint256 skipSeals,
        bytes32[2] memory padDigest
    )
        internal
        view
        returns (
            bytes32[2] memory recallSeed,
            bytes32[UNITS_PER_SEAL] memory mixedData
        )
    {
        for (uint256 i = 0; i < skipSeals; i += 1) {
            for (uint256 j = 0; j < BHASHES_PER_SEAL; j += 1) {
                padDigest = Blake2b.blake2b(padDigest);
            }
        }

        for (uint256 i = 0; i < UNITS_PER_SEAL; i += 2) {
            padDigest = Blake2b.blake2b(padDigest);
            mixedData[i] = padDigest[0] ^ sealedData[i];
            mixedData[i + 1] = padDigest[1] ^ sealedData[i + 1];
        }

        for (uint256 i = skipSeals + 1; i < SEALS_PER_PAD; i += 1) {
            for (uint256 j = 0; j < BHASHES_PER_SEAL; j += 1) {
                padDigest = Blake2b.blake2b(padDigest);
            }
        }

        recallSeed = padDigest;
    }

    function computePoraHash(
        uint256 sealOffset,
        bytes32[2] memory padSeed,
        bytes32[UNITS_PER_SEAL] memory mixedData
    ) internal view returns (bytes32) {
        bytes32[2] memory h;
        h[0] = Blake2b.BLAKE2B_INIT_STATE0;
        h[1] = Blake2b.BLAKE2B_INIT_STATE1;

        h = Blake2b.blake2bF(
            h,
            bytes32(sealOffset),
            padSeed[0],
            padSeed[1],
            bytes32(0),
            128,
            false
        );
        for (uint256 i = 0; i < UNITS_PER_SEAL - 4; i += 4) {
            uint256 length;
            unchecked {
                length = 128 + 32 * (i + 4);
            }
            h = Blake2b.blake2bF(
                h,
                mixedData[i],
                mixedData[i + 1],
                mixedData[i + 2],
                mixedData[i + 3],
                length,
                false
            );
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
}
