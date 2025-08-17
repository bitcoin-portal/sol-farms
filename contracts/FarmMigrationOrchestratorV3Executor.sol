// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./FarmMigrationOrchestratorV3Router.sol";
import "forge-std/console2.sol";

/**
 * @title FarmMigrationOrchestratorV3Executor
 * @notice Executes the complete migration process from FarmA to FarmB
 * @dev Inherits from FarmMigrationOrchestratorV3Router to access all the core functionality
 */
contract FarmMigrationOrchestratorV3Executor is FarmMigrationOrchestratorV3Router {

    constructor(
        address _simpleFarmA,
        address _simpleFarmB,
        address _verseToken,
        address _tbtcToken,
        address _balancerPool,
        address _balancerRouter
    ) FarmMigrationOrchestratorV3Router(
        _simpleFarmA,
        _simpleFarmB,
        _verseToken,
        _tbtcToken,
        _balancerPool,
        _balancerRouter
    ) {}

    /**
     * @notice Execute the complete migration process
     * @param _farmReceiptAmount Amount of SimpleFarmA receipt tokens to migrate
     * @param _verseToSwap Amount of VERSE to swap for tBTC
     * @param _minTbtcOut Minimum tBTC to receive from swap
     * @param _deadline Transaction deadline
     */
    function executeMigration(
        uint256 _farmReceiptAmount,
        uint256 _verseToSwap,
        uint256 _minTbtcOut,
        uint256 _deadline
    )
        external
        override
    {
        // Step 1: Transfer SimpleFarmA receipt tokens from user to orchestrator
        require(
            simpleFarmA.transferFrom(msg.sender, address(this), _farmReceiptAmount),
            "FarmMigrationOrchestratorV3Executor: RECEIPT_TRANSFER_FAILED"
        );

        // Step 2: Withdraw VERSE from SimpleFarmA
        simpleFarmA.farmWithdraw(_farmReceiptAmount);

        // Check VERSE balance received
        uint256 verseBalance = verseToken.balanceOf(address(this));
        require(verseBalance >= _verseToSwap, "FarmMigrationOrchestratorV3Executor: INSUFFICIENT_VERSE");

        // Step 3: Use the actual VERSE balance from FarmA withdrawal
        uint256 verseToUse = verseBalance; // Use whatever VERSE we got from FarmA

        // For testing, let's use the actual available balance
        console2.log("Available VERSE balance:", verseBalance);
        console2.log("Using VERSE amount:", verseToUse);

        // Step 3: Execute swap directly (skip quote for now)
        uint256 verseToSwapAmount = (verseToUse * 20) / 100; // 20% of VERSE

        console2.log("Swapping VERSE to tBTC:", verseToSwapAmount);

        // Validate deadline
        require(block.timestamp <= _deadline, "FarmMigrationOrchestratorV3Executor: DEADLINE_EXPIRED");

        // Execute the swap
        uint256 tbtcReceived = _swapVerseToTbtcViaRouter(verseToSwapAmount, _minTbtcOut, _deadline);

        // Step 4: Add balanced liquidity with remaining VERSE and received tBTC
        uint256 remainingVerse = verseToUse - verseToSwapAmount; // 80% of VERSE

        console2.log("Adding liquidity with:");
        console2.log("  VERSE amount:", remainingVerse);
        console2.log("  tBTC amount:", tbtcReceived);

        // Use the working addLiquidity approach
        uint256 lpTokensReceived = addLiquidity(remainingVerse, tbtcReceived);

        console2.log("LP tokens received:", lpTokensReceived);

        // Step 5: Stake LP tokens in SimpleFarmB (if we received any)
        if (lpTokensReceived > 0) {
            lpToken.approve(address(simpleFarmB), lpTokensReceived);
            simpleFarmB.farmDeposit(lpTokensReceived);

            // Step 6: Transfer SimpleFarmB receipt tokens to user
            uint256 farmBBalance = simpleFarmB.balanceOf(address(this));
            require(
                simpleFarmB.transfer(msg.sender, farmBBalance),
                "FarmMigrationOrchestratorV3Executor: FARMB_TRANSFER_FAILED"
            );
        }

        // Transfer any remaining VERSE back to user
        uint256 finalVerseBalance = verseToken.balanceOf(address(this));
        if (finalVerseBalance > 0) {
            safeTransfer(verseToken, msg.sender, finalVerseBalance);
        }

        // Transfer any remaining tBTC back to user
        uint256 remainingTbtc = tbtcToken.balanceOf(address(this));
        if (remainingTbtc > 0) {
            safeTransfer(tbtcToken, msg.sender, remainingTbtc);
        }

        emit MigrationCompleted(
            msg.sender,
            _farmReceiptAmount,
            tbtcReceived,
            lpTokensReceived,
            lpTokensReceived > 0 ? simpleFarmB.balanceOf(address(this)) : 0
        );
    }
}
