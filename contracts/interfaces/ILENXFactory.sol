// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface ILENXFactory {
    function flashOn() external view returns (bool);

    function flashFee() external view returns (uint);

    function createFee() external view returns (uint);

    function feeToken() external view returns (address);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function migrators(address migrator) external view returns (bool);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);
}
