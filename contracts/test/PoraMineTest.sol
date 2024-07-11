// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../miner/Mine.sol";
import "../miner/MineLib.sol";

contract PoraMineTest is PoraMine {
    // 1, 1, settings | 0x4
    constructor(uint settings) PoraMine(settings | 0x4) {}

    function setMiner(bytes32 minerId) external {
        beneficiaries[minerId] = msg.sender;
    }

    function setQuality(uint _targetQuality) external {
        poraTarget = _targetQuality;
    }

    function unseal(
        MineLib.PoraAnswer memory answer
    ) external pure returns (bytes32[UNITS_PER_SEAL] memory unsealedData) {
        return MineLib.unseal(answer);
    }

    function recoverMerkleRoot(
        MineLib.PoraAnswer memory answer,
        bytes32[UNITS_PER_SEAL] memory unsealedData
    ) external pure returns (bytes32) {
        return MineLib.recoverMerkleRoot(answer, unsealedData);
    }
}
