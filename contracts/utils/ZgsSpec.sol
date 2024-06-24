// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

uint constant KB = 1024;
uint constant MB = 1024 * KB;
uint constant GB = 1024 * MB;
uint constant TB = 1024 * GB;

uint constant MAX_MINING_LENGTH = (8 * TB) / BYTES_PER_SECTOR;

uint constant BYTES_PER_SECTOR = 256;
uint constant BYTES_PER_SEAL = 4 * KB;
uint constant BYTES_PER_PAD = 64 * KB;
uint constant BYTES_PER_LOAD = 256 * KB;
uint constant BYTES_PER_PRICE = 8 * GB;

uint constant BYTES_PER_UNIT = 32;
uint constant BYTES_PER_BHASH = 64;

uint constant UNITS_PER_SECTOR = BYTES_PER_SECTOR / BYTES_PER_UNIT;
uint constant UNITS_PER_SEAL = BYTES_PER_SEAL / BYTES_PER_UNIT;

uint constant SECTORS_PER_SEAL = BYTES_PER_SEAL / BYTES_PER_SECTOR;
uint constant SECTORS_PER_PRICE = BYTES_PER_PRICE / BYTES_PER_SECTOR;
uint constant SECTORS_PER_LOAD = BYTES_PER_LOAD / BYTES_PER_SECTOR;

uint constant SEALS_PER_LOAD = BYTES_PER_LOAD / BYTES_PER_SEAL;
uint constant PADS_PER_LOAD = BYTES_PER_LOAD / BYTES_PER_PAD;

uint constant SEALS_PER_PAD = SEALS_PER_LOAD / PADS_PER_LOAD;
uint constant BHASHES_PER_SEAL = BYTES_PER_SEAL / BYTES_PER_BHASH;

uint constant UNITS_PER_ZGS_TOKEN = 1_000_000_000_000_000_000;

uint constant DAYS_PER_MONTH = 31;
uint constant SECONDS_PER_MONTH = 86400 * DAYS_PER_MONTH;

uint constant MONTH_PER_YEAR = 12;
uint constant DAYS_PER_YEAR = MONTH_PER_YEAR * DAYS_PER_MONTH;
uint constant SECONDS_PER_YEAR = 86400 * DAYS_PER_YEAR;
uint constant MILLI_SECONDS_PER_YEAR = 1000 * SECONDS_PER_YEAR;
