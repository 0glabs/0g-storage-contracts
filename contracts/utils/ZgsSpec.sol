// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

uint256 constant KB = 1024;
uint256 constant MB = 1024 * KB;
uint256 constant GB = 1024 * MB;
uint256 constant TB = 1024 * GB;

uint256 constant MAX_MINING_LENGTH = 8 * TB / BYTES_PER_SECTOR;

uint256 constant BYTES_PER_SECTOR = 256;
uint256 constant BYTES_PER_SEAL = 4 * KB;
uint256 constant BYTES_PER_PAD = 64 * KB;
uint256 constant BYTES_PER_LOAD = 256 * KB;
uint256 constant BYTES_PER_PRICE = 8 * GB;

uint256 constant BYTES_PER_UNIT = 32;
uint256 constant BYTES_PER_BHASH = 64;

uint256 constant UNITS_PER_SECTOR = BYTES_PER_SECTOR / BYTES_PER_UNIT;
uint256 constant UNITS_PER_SEAL = BYTES_PER_SEAL / BYTES_PER_UNIT;

uint256 constant SECTORS_PER_SEAL = BYTES_PER_SEAL / BYTES_PER_SECTOR;
uint256 constant SECTORS_PER_PRICE = BYTES_PER_PRICE / BYTES_PER_SECTOR;
uint256 constant SECTORS_PER_LOAD = BYTES_PER_LOAD / BYTES_PER_SECTOR;

uint256 constant SEALS_PER_LOAD = BYTES_PER_LOAD / BYTES_PER_SEAL;
uint256 constant PADS_PER_LOAD = BYTES_PER_LOAD / BYTES_PER_PAD;

uint256 constant SEALS_PER_PAD = SEALS_PER_LOAD / PADS_PER_LOAD;
uint256 constant BHASHES_PER_SEAL = BYTES_PER_SEAL / BYTES_PER_BHASH;