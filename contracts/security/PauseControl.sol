// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.2;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

contract PauseControl is PausableUpgradeable, AccessControlEnumerableUpgradeable {
    // role
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
