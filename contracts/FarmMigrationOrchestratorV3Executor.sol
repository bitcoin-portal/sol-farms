// SPDX-License-Identifier: -- BCOM --

pragma solidity ^0.8.26;

import "./FarmMigrationOrchestratorV3Router.sol";

/**
 * @title FarmMigrationOrchestratorV3Executor
 * @notice Executes the complete migration process from FarmA to FarmB
 * @dev Inherits from FarmMigrationOrchestratorV3Router to access all the core functionality
 */
contract FarmMigrationOrchestratorV3Executor is FarmMigrationOrchestratorV3Router {

    address public owner;
    address public proposedOwner;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "INVALID_OWNER"
        );
        _;
    }

    event OwnerProposed(
        address indexed newOwner
    );

    event OwnerChanged(
        address indexed newOwner
    );

    event MigrationCompleted(
        address indexed user,
        uint256 verseWithdrawn,
        uint256 tbtcSwapped,
        uint256 lpTokensAcquired,
        uint256 lpTokensStaked
    );

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
    ) {
        owner = msg.sender;
    }

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
    {
        simpleFarmA.transferFrom(
            msg.sender,
            address(this),
            _farmReceiptAmount
        );

        simpleFarmA.farmWithdraw(
            _farmReceiptAmount
        );

        uint256 verseBalance = verseToken.balanceOf(
            address(this)
        );

        require(
            verseBalance >= _verseToSwap,
            "INSUFFICIENT_VERSE"
        );

        uint256 verseToUse = verseBalance;
        uint256 verseToSwapAmount = verseToUse
            * 20
            / 100;

        require(
            block.timestamp <= _deadline,
            "DEADLINE_EXPIRED"
        );

        uint256 tbtcReceived = _swapVerseToTbtcViaRouter(
            verseToSwapAmount,
            _minTbtcOut,
            _deadline
        );

        uint256 remainingVerse = verseToUse
            - verseToSwapAmount;

        uint256 lpTokensReceived = _addLiquidity(
            remainingVerse,
            tbtcReceived,
            _deadline
        );

        if (lpTokensReceived > 0) {

            lpToken.approve(
                address(simpleFarmB),
                lpTokensReceived
            );

            simpleFarmB.farmDeposit(
                lpTokensReceived
            );

            uint256 farmBBalance = simpleFarmB.balanceOf(
                address(this)
            );

            simpleFarmB.transfer(
                msg.sender,
                farmBBalance
            );
        }

        uint256 finalVerseBalance = verseToken.balanceOf(
            address(this)
        );

        if (finalVerseBalance > 0) {
            safeTransfer(
                verseToken,
                msg.sender,
                finalVerseBalance
            );
        }

        uint256 remainingTbtc = tbtcToken.balanceOf(
            address(this)
        );

        if (remainingTbtc > 0) {
            safeTransfer(
                tbtcToken,
                msg.sender,
                remainingTbtc
            );
        }

        emit MigrationCompleted(
            msg.sender,
            _farmReceiptAmount,
            tbtcReceived,
            lpTokensReceived,
            lpTokensReceived > 0
                ? simpleFarmB.balanceOf(address(this))
                : 0
        );
    }

    /**
     * @notice Propose a new owner
     */
    function proposeOwner(
        address _proposedOwner
    )
        external
        onlyOwner
    {
        proposedOwner = _proposedOwner;

        emit OwnerProposed(
            _proposedOwner
        );
    }

    /**
     * @notice Accept ownership
     */
    function acceptOwnership()
        external
    {
        require(
            msg.sender == proposedOwner,
            "INVALID_PROPOSED_OWNER"
        );

        owner = msg.sender;
        proposedOwner = address(0x0);

        emit OwnerChanged(
            msg.sender
        );
    }

    /**
     * @notice Emergency withdraw function
     */
    function emergencyWithdraw(
        IERC20 _token,
        uint256 _amount
    )
        external
        onlyOwner
    {
        safeTransfer(
            _token,
            owner,
            _amount
        );
    }

    /**
     * @notice Get pool information
     */
    function getPoolInfo()
        external
        view
        returns (
            address[] memory tokens,
            uint256 totalSupply,
            uint256 poolBalance
        )
    {
        tokens = balancerPool.getTokens();
        totalSupply = balancerPool.totalSupply();

        poolBalance = balancerPool.balanceOf(
            address(this)
        );
    }
}
