// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/ZgsSpec.sol";
import "../utils/Blake2b.sol";


library MineLib {
    function computeScratchPadAndMix(bytes32[UNITS_PER_SEAL] memory sealedData, uint skipSeals, bytes32[2] memory padDigest) internal view returns (bytes32[2] memory recallSeed, bytes32[UNITS_PER_SEAL] memory mixedData)  {
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
}