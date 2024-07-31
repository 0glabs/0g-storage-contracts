// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

interface IMarket {
    function chargeFee(uint beforeLength, uint uploadSectors, uint paddingSectors) external;

    function flow() external view returns (address);

    function pricePerSector() external view returns (uint);

    function reward() external view returns (address);

    function setPricePerSector(uint pricePerSector_) external;
}
