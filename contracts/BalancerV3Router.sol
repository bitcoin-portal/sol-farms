// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import "./IERC20.sol";

// Balancer V3 Router Interface
// Based on the actual V3 Router deployed at 0xAE563E3f8219521950555F5962419C8919758Ea2
interface IBalancerV3Router {

    // Request structs
    struct AddLiquidityProportionalRequest {
        address pool;
        uint256[] maxAmountsIn; // scaled to pool decimals
        address sender;
        address recipient;
        bytes userData;         // leave empty for simple joins
    }

    struct AddLiquidityUnbalancedRequest {
        address pool;
        uint256[] maxAmountsIn; // put zeros for tokens you don't want to use
        address sender;
        address recipient;
        bytes userData;
    }

    struct AddLiquiditySingleTokenExactInRequest {
        address pool;
        address tokenIn;
        uint256 amountIn;
        address sender;
        address recipient;
        bytes userData;
    }

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

    // --- Query functions (staticcall) ---
    function queryAddLiquidityProportional(
        AddLiquidityProportionalRequest calldata req
    ) external view returns (uint256 bptAmountOut);

    function queryAddLiquidityUnbalanced(
        AddLiquidityUnbalancedRequest calldata req
    ) external view returns (uint256 bptAmountOut);

    function queryAddLiquiditySingleTokenExactIn(
        AddLiquiditySingleTokenExactInRequest calldata req
    ) external view returns (uint256 bptAmountOut);

    // Legacy query functions (keeping for backward compatibility)
    function querySwapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        address sender,
        bytes calldata userData
    ) external returns (uint256 amountOut);

    function queryAddLiquidityUnbalanced(
        address pool,
        uint256[] memory exactAmountsIn,
        address sender,
        bytes calldata userData
    ) external returns (uint256 bptAmountOut);

    // Query add liquidity proportional
    function queryAddLiquidityProportional(
        address pool,
        uint256[] memory maxAmountsIn,
        address sender,
        bytes calldata userData
    ) external returns (uint256 bptAmountOut);
}
