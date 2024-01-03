// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "../utils/Blake2b.sol";

contract Blake2bTest {
    function blake2bPair(bytes32[2] memory input)
        external
        view
        returns (bytes32[2] memory h)
    {
        return Blake2b.blake2b(input);
    }

    function blake2bTriple(bytes32[3] memory input)
        external
        view
        returns (bytes32[2] memory h)
    {
        return Blake2b.blake2b(input);
    }

    function blake2bFive(bytes32[5] memory input)
        external
        view
        returns (bytes32[2] memory h)
    {
        return Blake2b.blake2b(input);
    }

    function blake2b(bytes32[] memory input)
        external
        view
        returns (bytes32[2] memory h)
    {
        return Blake2b.blake2b(input);
    }
}
