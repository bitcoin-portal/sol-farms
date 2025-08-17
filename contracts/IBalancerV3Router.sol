// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import "./IERC20.sol";

// Balancer V3 Router Interface
// Based on the actual V3 Router deployed at 0xAE563E3f8219521950555F5962419C8919758Ea2
interface IBalancerV3Router {

    // Swap function for single token exact in
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256 amountOut);

    // Add liquidity unbalanced (for adding liquidity with custom amounts)
    function addLiquidityUnbalanced(
        address pool,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256 bptAmountOut);

    // Add liquidity proportional
    function addLiquidityProportional(
        address pool,
        uint256[] memory maxAmountsIn,
        uint256 exactBptAmountOut,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256[] memory amountsIn);

    // Add liquidity single token exact out
    function addLiquiditySingleTokenExactOut(
        address pool,
        IERC20 tokenIn,
        uint256 maxAmountIn,
        uint256 exactBptAmountOut,
        bool wethIsEth,
        bytes calldata userData
    ) external payable returns (uint256 amountIn);
}
