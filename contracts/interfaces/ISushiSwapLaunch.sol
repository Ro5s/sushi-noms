/// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/// @notice Interface for SushiSwap pair creation and ETH liquidity provision.
interface ISushiSwapLaunch {
    function approve(address to, uint amount) external returns (bool); 
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}
