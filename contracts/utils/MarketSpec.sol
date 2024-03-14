// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "./ZgsSpec.sol";

uint256 constant ANNUAL_ZGS_TOKENS_PER_GB = 10;
uint256 constant SECOND_ZGS_UNITS_PER_PRICE = (BYTES_PER_PRICE *
    ANNUAL_ZGS_TOKENS_PER_GB *
    UNITS_PER_ZGS_TOKEN) /
    GB /
    SECONDS_PER_YEAR;

uint256 constant MONTH_ZGS_UNITS_PER_SECTOR = (BYTES_PER_SECTOR *
    ANNUAL_ZGS_TOKENS_PER_GB *
    UNITS_PER_ZGS_TOKEN) /
    GB /
    MONTH_PER_YEAR;

uint256 constant ANNUAL_MILLI_DECAY_RATE = 40;
