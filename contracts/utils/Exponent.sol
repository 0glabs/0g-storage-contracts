// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;
import "./BitMask.sol";
import "./UncheckedMath.sol";
import "hardhat/console.sol";

library Exponential {
    int256 private constant LOG2X128 = 235865763225513294137944142764154484399;
    int256 private constant LOG2_2X128 =
        163489688770384171654468164494102986538;
    int256 private constant LOG2_3X128 =
        113322416821814740463990287346838243787;
    int256 private constant LOG2_4X128 = 78549113714279805586246364391047974677;

    uint256 private constant ROOT_POW10X127 =
        0x8016302f174676283690dfe44d11d008;
    uint256 private constant ROOT_POW9X127 = 0x802c6436d0e04f50ff8ce94a6797b3ce;
    uint256 private constant ROOT_POW8X127 = 0x8058d7d2d5e5f6b094d589f608ee4aa2;
    uint256 private constant ROOT_POW7X127 = 0x80b1ed4fd999ab6c25335719b6e6fd20;
    uint256 private constant ROOT_POW6X127 = 0x8164d1f3bc0307737be56527bd14def4;
    uint256 private constant ROOT_POW5X127 = 0x82cd8698ac2ba1d73e2a475b46520bff;
    uint256 private constant ROOT_POW4X127 = 0x85aac367cc487b14c5c95b8c2154c1b2;
    uint256 private constant ROOT_POW3X127 = 0x8b95c1e3ea8bd6e6fbe4628758a53c90;
    uint256 private constant ROOT_POW2X127 = 0x9837f0518db8a96f46ad23182e42f6f6;
    uint256 private constant ROOT_POW1X127 = 0xb504f333f9de6484597d89b3754abe9f;

    uint256 private constant REV_ROOT_POW10X128 =
        0xffd3a751c0f7e10bd3b9f8ae012fbe06;
    uint256 private constant REV_ROOT_POW9X128 =
        0xffa756521c8daed19f3a1b48fb94c589;
    uint256 private constant REV_ROOT_POW8X128 =
        0xff4ecb59511ec8a5301ba217ef18dd7c;
    uint256 private constant REV_ROOT_POW7X128 =
        0xfe9e115c7b8f884badd25995e79d2f09;
    uint256 private constant REV_ROOT_POW6X128 =
        0xfd3e0c0cf486c174853f3a5931e0ee03;
    uint256 private constant REV_ROOT_POW5X128 =
        0xfa83b2db722a033a7c25bb14315d7fcc;
    uint256 private constant REV_ROOT_POW4X128 =
        0xf5257d152486cc2c7b9d0c7aed980fc3;
    uint256 private constant REV_ROOT_POW3X128 =
        0xeac0c6e7dd24392ed02d75b3706e54fa;
    uint256 private constant REV_ROOT_POW2X128 =
        0xd744fccad69d6af439a68bb9902d3fde;
    uint256 private constant REV_ROOT_POW1X128 =
        0xb504f333f9de6484597d89b3754abe9f;

    function powTwo64X96(uint256 exponentX64)
        internal
        pure
        returns (uint256 powerX96)
    {
        uint256 fractionSmallX64 = exponentX64 & 0x3fffffffffffff;
        uint256 fractionLargeX64 = exponentX64 & 0xffc0000000000000;
        uint256 integer = exponentX64 >> 64;
        if (integer >= 160) {
            return type(uint256).max;
        }

        uint256 powerX127 = _talorExpand64X127(int256(fractionSmallX64));
        // console.log("fractionLargeX64 = %d", fractionLargeX64);
        // console.log("powerX127 = %d", powerX127 - (1<<127));
        if ((fractionLargeX64 & BIT54) != 0) {
            unchecked {
                powerX127 *= ROOT_POW10X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT55) != 0) {
            unchecked {
                powerX127 *= ROOT_POW9X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT56) != 0) {
            unchecked {
                powerX127 *= ROOT_POW8X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT57) != 0) {
            unchecked {
                powerX127 *= ROOT_POW7X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT58) != 0) {
            unchecked {
                powerX127 *= ROOT_POW6X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT59) != 0) {
            unchecked {
                powerX127 *= ROOT_POW5X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT60) != 0) {
            unchecked {
                powerX127 *= ROOT_POW4X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT61) != 0) {
            unchecked {
                powerX127 *= ROOT_POW3X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT62) != 0) {
            unchecked {
                powerX127 *= ROOT_POW2X127;
            }
            powerX127 >>= 127;
        }
        if ((fractionLargeX64 & BIT63) != 0) {
            unchecked {
                powerX127 *= ROOT_POW1X127;
            }
            powerX127 >>= 127;
        }
        // console.log("powerX127 = %d", powerX127 - (1<<127));

        if (integer < 31) {
            powerX96 = powerX127 >> (31 - integer);
        } else {
            powerX96 = powerX127 << (integer - 31);
        }
        // console.log("powerX96 = %d", powerX96 - (1<<96));
    }

    function powHalf64X96(uint256 exponentX64)
        internal
        pure
        returns (uint256 powerX96)
    {
        uint256 fractionSmallX64 = exponentX64 & 0x3fffffffffffff;
        uint256 fractionLargeX64 = exponentX64 & 0xffc0000000000000;
        uint256 integer = exponentX64 >> 64;

        uint256 powerX127 = _talorExpand64X127(-int256(fractionSmallX64));
        if ((fractionLargeX64 & BIT54) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW10X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT55) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW9X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT56) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW8X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT57) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW7X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT58) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW6X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT59) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW5X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT60) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW4X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT61) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW3X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT62) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW2X128;
            }
            powerX127 >>= 128;
        }
        if ((fractionLargeX64 & BIT63) != 0) {
            unchecked {
                powerX127 *= REV_ROOT_POW1X128;
            }
            powerX127 >>= 128;
        }

        powerX96 = powerX127 >> (31 + integer);
    }

    function _talorExpand64X127(int256 exponentX64)
        internal
        pure
        returns (uint256 powerX127)
    {
        unchecked {
            if (exponentX64 == 0) {
                return 1 << 127;
            }
            int256 x = exponentX64 << 63;
            int256 x2 = (x * x) >> 127;
            int256 x3 = (x2 * x) >> 127;
            int256 x4 = (x3 * x) >> 127;

            int256 powerX128 = 0;
            // 2^x = e^(ln(2) * x) = 1 + ln(2) * x + ln(2)^2 * x^2 / 2 + ln(2)^3 * x^3 / 6 + ln(2)^4 * x^4 / 24
            powerX128 += 1 << 128; // 1
            powerX128 += (x * LOG2X128) >> 127; // x
            powerX128 += (x2 * LOG2_2X128) >> 128; // x^2 / 2
            powerX128 += ((x3 * LOG2_3X128) >> 127) / 6; // x^3 / 6
            powerX128 += ((x4 * LOG2_4X128) >> 127) / 24; // x^4 / 24

            powerX127 = uint256(powerX128) >> 1;
        }
    }
}
