// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./UncheckedMath.sol";

library Blake2b {
    using UncheckedMath for uint256;
    bytes32 constant BLAKE2B_INIT_STATE0 =
        hex"48c9bdf267e6096a3ba7ca8485ae67bb2bf894fe72f36e3cf1361d5f3af54fa5";
    bytes32 constant BLAKE2B_INIT_STATE1 =
        hex"d182e6ad7f520e511f6c3e2b8c68059b6bbd41fbabd9831f79217e1319cde05b";

    function blake2b(bytes32[2] memory input)
        internal
        view
        returns (bytes32[2] memory h)
    {
        h[0] = BLAKE2B_INIT_STATE0;
        h[1] = BLAKE2B_INIT_STATE1;

        h = blake2bF(
            h,
            input[0],
            input[1],
            bytes32(0x0),
            bytes32(0x0),
            64,
            true
        );
    }

    function blake2b(bytes32[3] memory input)
        internal
        view
        returns (bytes32[2] memory h)
    {
        h[0] = BLAKE2B_INIT_STATE0;
        h[1] = BLAKE2B_INIT_STATE1;

        h = blake2bF(h, input[0], input[1], input[2], bytes32(0x0), 96, true);
    }

    function blake2b(bytes32[5] memory input)
        internal
        view
        returns (bytes32[2] memory h)
    {
        h[0] = BLAKE2B_INIT_STATE0;
        h[1] = BLAKE2B_INIT_STATE1;

        h = blake2bF(h, input[0], input[1], input[2], input[3], 128, false);
        h = blake2bF(
            h,
            input[4],
            bytes32(0x0),
            bytes32(0x0),
            bytes32(0x0),
            160,
            true
        );
    }

    function blake2b(bytes32[] memory input)
        internal
        view
        returns (bytes32[2] memory h)
    {
        h[0] = BLAKE2B_INIT_STATE0;
        h[1] = BLAKE2B_INIT_STATE1;
        if (input.length == 0) {
            h = blake2bF(
                h,
                bytes32(0x0),
                bytes32(0x0),
                bytes32(0x0),
                bytes32(0x0),
                0,
                true
            );
        }
        for (uint256 i = 0; i < input.length; i += 4) {
            bytes32 m0 = input[i];
            bytes32 m1 = bytes32(0x0);
            bytes32 m2 = bytes32(0x0);
            bytes32 m3 = bytes32(0x0);
            bool finalize = (i + 4 >= input.length);
            uint256 length = (i + 4) * 32;

            if (!finalize) {
                m1 = input[i + 1];
                m2 = input[i + 2];
                m3 = input[i + 3];
            } else {
                length = input.length * 32;
                if (i + 1 < input.length) {
                    m1 = input[i + 1];
                    if (i + 2 < input.length) {
                        m2 = input[i + 2];
                        if (i + 3 < input.length) {
                            m3 = input[i + 3];
                        }
                    }
                }
            }

            h = blake2bF(h, m0, m1, m2, m3, length, finalize);
        }
    }

    function blake2bF(
        bytes32[2] memory h,
        bytes32 m0,
        bytes32 m1,
        bytes32 m2,
        bytes32 m3,
        uint256 offset,
        bool finalize
    ) internal view returns (bytes32[2] memory output) {
        uint32 rounds = 12;

        bytes8[2] memory t = blake2bLength(offset);
        bytes memory args = abi.encodePacked(
            rounds,
            h[0],
            h[1],
            m0,
            m1,
            m2,
            m3,
            t[0],
            t[1],
            finalize
        );

        assembly {
            if iszero(
                staticcall(not(0), 0x09, add(args, 32), 0xd5, output, 0x40)
            ) {
                revert(0, 0)
            }
        }
    }

    function blake2bLength(uint256 length)
        internal
        pure
        returns (bytes8[2] memory t)
    {
        if (length < (1 << 16)) {
            t[0] = reverse16(uint64(length));
            t[1] = bytes8(0x0);
        } else if (length < (1 << 32)) {
            t[0] = reverse32(uint64(length));
            t[1] = bytes8(0x0);
        } else if (length < (1 << 64)) {
            t[0] = reverse64(uint64(length));
            t[1] = bytes8(0x0);
        } else if (length < (1 << 128)) {
            uint64 lower = uint64(length & 0xFFFFFFFFFFFFFFFF);
            uint64 higher = uint64(length >> 64);
            t[0] = reverse64(lower);
            t[1] = reverse64(higher);
        } else {
            revert("blake2b input too long");
        }
    }

    function reverse16(uint64 _v) internal pure returns (bytes8) {
        uint64 v = _v;
        // swap bytes
        v = (v >> 8) | (v << 8);
        v <<= 48;

        return bytes8(v);
    }

    function reverse32(uint64 _v) internal pure returns (bytes8) {
        uint64 v = _v;
        // swap bytes
        v = ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);

        // swap 2-byte long pairs
        v = (v >> 16) | (v << 16);

        v <<= 32;

        return bytes8(v);
    }

    function reverse64(uint64 _v) internal pure returns (bytes8) {
        uint64 v = _v;
        // swap bytes
        v = ((v & 0xFF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF) << 8);

        // swap 2-byte long pairs
        v = ((v & 0xFFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF) << 16);

        // swap 4-byte long pairs
        v = (v >> 32) | (v << 32);

        return bytes8(v);
    }
}
