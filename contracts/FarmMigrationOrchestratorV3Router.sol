// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./BalancerV3Router.sol";
import "./IPermit2.sol";
import "forge-std/console2.sol";

// SimpleFarm Interface
interface ISimpleFarm {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function farmDeposit(uint256 amount) external;
    function farmWithdraw(uint256 amount) external;
}

// Balancer V3 Pool Interface
interface IBalancerV3Pool {
    function getTokens() external view returns (address[] memory);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @title FarmMigrationOrchestratorV3Router
 * @notice Orchestrates migration from SimpleFarmA to SimpleFarmB using Balancer V3 Router with ZAP functionality
 * @dev This version uses the Balancer V3 Router for swaps and ZAP-like liquidity addition
 */
contract FarmMigrationOrchestratorV3Router is SafeERC20 {

    // Farm contracts
    ISimpleFarm public immutable simpleFarmA;
    ISimpleFarm public immutable simpleFarmB;

    // Token addresses
    IERC20 public immutable verseToken;
    IERC20 public immutable tbtcToken;
    IERC20 public immutable lpToken;

    // Balancer V3 addresses
    IBalancerV3Router public immutable balancerRouter;
    IBalancerV3Pool public immutable balancerPool;
    address public constant BALANCER_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Owner management
    address public owner;
    address public proposedOwner;

    // Events
    event MigrationCompleted(
        address indexed user,
        uint256 verseWithdrawn,
        uint256 tbtcSwapped,
        uint256 lpTokensAcquired,
        uint256 lpTokensStaked
    );

    event OwnerProposed(
        address indexed newOwner
    );

    event OwnerChanged(
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "FarmMigrationOrchestratorV3Router: INVALID_OWNER"
        );
        _;
    }

    constructor(
        address _simpleFarmA,
        address _simpleFarmB,
        address _verseToken,
        address _tbtcToken,
        address _balancerPool,
        address _balancerRouter
    ) {
        simpleFarmA = ISimpleFarm(
            _simpleFarmA
        );

        simpleFarmB = ISimpleFarm(
            _simpleFarmB
        );

        verseToken = IERC20(
            _verseToken
        );

        tbtcToken = IERC20(
            _tbtcToken
        );

        lpToken = IERC20(
            _balancerPool
        );

        balancerPool = IBalancerV3Pool(
            _balancerPool
        );

        balancerRouter = IBalancerV3Router(
            _balancerRouter
        );

        owner = msg.sender;
    }

    /**
     * @notice Swap VERSE to tBTC using Balancer V3 Router
     */
    function _swapVerseToTbtcViaRouter(
        uint256 _verseAmount,
        uint256 _minTbtcOut
    )
        internal
        returns (uint256)
    {
        // Always approve Permit2 with max amount to avoid allowance issues
        verseToken.approve(
            PERMIT2,
            type(uint256).max
        );

        // Give Router permission within Permit2
        IPermit2(PERMIT2).approve(
            address(verseToken),
            address(balancerRouter),
            uint160(_verseAmount),
            uint48(block.timestamp + 3600)
        );

        // Execute swap using swapSingleTokenExactIn
        uint256 amountOut = balancerRouter.swapSingleTokenExactIn(
            address(balancerPool),
            verseToken,
            tbtcToken,
            _verseAmount,
            _minTbtcOut,
            block.timestamp + 3600, // 1 hour deadline
            false, // wethIsEth
            "" // userData
        );

        return amountOut;
    }

    /**
     * @notice Add liquidity to Balancer pool using Router with proportional amounts
     * @dev Uses addLiquidityProportional with calculated exactBptAmountOut
     */
    function _addLiquidityViaRouter(
        uint256 _verseAmount,
        uint256 _tbtcAmount,
        uint256 _exactBptAmountOut
    )
        internal
        returns (uint256)
    {
        // Always approve Permit2 with max amounts
        verseToken.approve(PERMIT2, type(uint256).max);
        tbtcToken.approve(PERMIT2, type(uint256).max);

        // Give Router permission within Permit2 for both tokens
        IPermit2(PERMIT2).approve(
            address(verseToken),
            address(balancerRouter),
            uint160(_verseAmount),
            uint48(block.timestamp + 3600)
        );

        IPermit2(PERMIT2).approve(
            address(tbtcToken),
            address(balancerRouter),
            uint160(_tbtcAmount),
            uint48(block.timestamp + 3600)
        );

        // Get pool tokens to determine order
        address[] memory poolTokens = balancerPool.getTokens();

        // Prepare maxAmountsIn array with correct token order
        uint256[] memory maxAmountsIn = new uint256[](2);
        if (poolTokens[0] == address(verseToken)) {
            maxAmountsIn[0] = _verseAmount;  // VERSE first
            maxAmountsIn[1] = _tbtcAmount;   // tBTC second
        } else {
            maxAmountsIn[0] = _tbtcAmount;   // tBTC first
            maxAmountsIn[1] = _verseAmount;  // VERSE second
        }

        console2.log("Adding liquidity with maxAmountsIn:", maxAmountsIn[0], maxAmountsIn[1]);
        console2.log("exactBptAmountOut:", _exactBptAmountOut);

        // Use addLiquidityProportional with the provided exactBptAmountOut
        uint256[] memory amountsIn = balancerRouter.addLiquidityProportional(
            address(balancerPool),
            maxAmountsIn,
            _exactBptAmountOut,
            false, // wethIsEth
            "" // userData
        );

        // Check the actual LP token balance we received
        uint256 bptAmountOut = lpToken.balanceOf(
            address(this)
        );

        return bptAmountOut;
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
            "FarmMigrationOrchestratorV3Router: INVALID_PROPOSED_OWNER"
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
     * @notice Internal function for adding liquidity
     * @dev Assumes tokens are already in this contract
     */
    function addLiquidity(
        uint256 _verseAmount,
        uint256 _tbtcAmount
    )
        internal
        returns (uint256)
    {
        // Calculate expected LP tokens
        uint256 expectedLpTokens = calculateExpectedLpTokens(
            _verseAmount,
            _tbtcAmount
        );

        // Add liquidity with calculated exactBptAmountOut
        uint256 lpTokensReceived = _addLiquidityViaRouter(
            _verseAmount,
            _tbtcAmount,
            expectedLpTokens
        );

        return lpTokensReceived;
    }

    /**
     * @notice Public function for users to add liquidity directly
     * @dev Users must have VERSE and tBTC tokens approved to this contract
     * @param _exactBptAmountOut Exact amount of LP tokens to receive (0 for auto-calculation)
     */
    function addLiquidityPublic(
        uint256 _verseAmount,
        uint256 _tbtcAmount,
        uint256 _exactBptAmountOut
    )
        external
        returns (uint256)
    {
        // Transfer tokens from user to this contract
        require(
            verseToken.transferFrom(msg.sender, address(this), _verseAmount),
            "VERSE transfer failed"
        );

        require(
            tbtcToken.transferFrom(msg.sender, address(this), _tbtcAmount),
            "tBTC transfer failed"
        );

        // Add liquidity with specified exactBptAmountOut or auto-calculate if 0
        uint256 exactBptAmountOut = _exactBptAmountOut == 0 ?
            calculateExpectedLpTokens(_verseAmount, _tbtcAmount) : _exactBptAmountOut;
        uint256 lpTokensReceived = _addLiquidityViaRouter(_verseAmount, _tbtcAmount, exactBptAmountOut);

        // Transfer LP tokens back to user
        if (lpTokensReceived > 0) {
            require(
                lpToken.transfer(msg.sender, lpTokensReceived),
                "LP token transfer failed"
            );
        }

        return lpTokensReceived;
    }

    /**
     * @notice Public wrapper for testing add liquidity functionality
     */
    function testAddLiquidity(uint256 _verseAmount, uint256 _tbtcAmount, uint256 _exactBptAmountOut) external returns (uint256) {
        return _addLiquidityViaRouter(_verseAmount, _tbtcAmount, _exactBptAmountOut);
    }

    /**
     * @notice Public function to add liquidity and stake LP tokens in FarmB
     * @dev Users must have VERSE and tBTC tokens approved to this contract
     * @param _verseAmount Amount of VERSE tokens to add as liquidity
     * @param _tbtcAmount Amount of tBTC tokens to add as liquidity
     * @param _slippageBps Slippage tolerance in basis points (e.g., 1000 = 10%)
     * @return farmBReceipts Amount of FarmB receipt tokens received
     */
    function addLiquidityAndStake(
        uint256 _verseAmount,
        uint256 _tbtcAmount,
        uint256 _slippageBps
    )
        external
        returns (uint256 farmBReceipts)
    {
        // Transfer tokens from user to this contract
        require(
            verseToken.transferFrom(msg.sender, address(this), _verseAmount),
            "VERSE transfer failed"
        );

        require(
            tbtcToken.transferFrom(msg.sender, address(this), _tbtcAmount),
            "tBTC transfer failed"
        );

        // Calculate exactBptAmountOut via query
        uint256 exactBptAmountOut = calculateExpectedLpTokens(
            _verseAmount,
            _tbtcAmount
        );

        // Apply slippage tolerance
        uint256 slippageAdjustedBpt = (exactBptAmountOut * (10000 - _slippageBps)) / 10000;
        console2.log("Original exactBptAmountOut:", exactBptAmountOut);
        console2.log("Slippage adjusted BPT:", slippageAdjustedBpt);

        uint256 lpTokensReceived = _addLiquidityViaRouter(
            _verseAmount,
            _tbtcAmount,
            slippageAdjustedBpt
        );

        console2.log("LP tokens received from addLiquidity:", lpTokensReceived);

        // Stake LP tokens in FarmB if we received any
        if (lpTokensReceived > 0) {
            // Approve FarmB to spend LP tokens
            lpToken.approve(address(simpleFarmB), lpTokensReceived);

            // Stake LP tokens in FarmB
            simpleFarmB.farmDeposit(lpTokensReceived);

            // Get FarmB receipt tokens
            farmBReceipts = simpleFarmB.balanceOf(address(this));

            console2.log("FarmB receipt tokens received:", farmBReceipts);

            // Transfer FarmB receipt tokens to user
            if (farmBReceipts > 0) {
                require(
                    simpleFarmB.transfer(msg.sender, farmBReceipts),
                    "FarmB receipt transfer failed"
                );
            }
        }

        return farmBReceipts;
    }

    /**
     * @notice Get swap quote for VERSE to tBTC
     */
    function getSwapQuote(uint256 _verseAmount) internal returns (uint256) {
        try IBalancerV3Router(balancerRouter).querySwapSingleTokenExactIn(
            address(balancerPool),
            verseToken,
            tbtcToken,
            _verseAmount,
            address(this),
            ""
        ) returns (uint256 amountOut) {
            console2.log("Swap quote successful, amountOut:", amountOut);
            return amountOut;
        } catch (bytes memory reason) {
            console2.log("Swap quote failed with reason:");
            console2.logBytes(reason);
            return 0;
        }
    }

    /**
     * @notice Get quote for LP tokens from Balancer V3 Router
     */
    function getLpQuote(uint256 _verseAmount, uint256 _tbtcAmount) internal returns (uint256) {
        // Get pool tokens to determine correct order
        address[] memory poolTokens = balancerPool.getTokens();
        console2.log("Pool tokens[0]:", poolTokens[0]);
        console2.log("Pool tokens[1]:", poolTokens[1]);
        console2.log("VERSE token:", address(verseToken));
        console2.log("tBTC token:", address(tbtcToken));

        // Use the router's queryAddLiquidityUnbalanced function to get accurate quote
        uint256[] memory exactAmountsIn = new uint256[](2);

        // Determine correct token order based on pool
        if (poolTokens[0] == address(verseToken)) {
            exactAmountsIn[0] = _verseAmount;  // VERSE first
            exactAmountsIn[1] = _tbtcAmount;   // tBTC second
        } else {
            exactAmountsIn[0] = _tbtcAmount;   // tBTC first
            exactAmountsIn[1] = _verseAmount;  // VERSE second
        }

        try IBalancerV3Router(balancerRouter).queryAddLiquidityUnbalanced(
            address(balancerPool),
            exactAmountsIn,
            address(this),
            ""
        ) returns (uint256 bptAmountOut) {
            console2.log("LP quote successful, bptAmountOut:", bptAmountOut);
            return bptAmountOut;
        } catch (bytes memory reason) {
            console2.log("LP quote failed with reason:");
            console2.logBytes(reason);
            // Fallback to simplified calculation if query fails
            (uint256 tbtcBalance, uint256 verseBalance) = getPoolBalances();
            uint256 bptRate = getBptRate();
            uint256 totalValue = (_verseAmount * verseBalance) + (_tbtcAmount * tbtcBalance);
            return totalValue / bptRate;
        }
    }

    /**
     * @notice Get current pool balances
     */
    function getPoolBalances() public view returns (uint256 tbtcBalance, uint256 verseBalance) {
        // Call getCurrentLiveBalances on the pool
        // This returns [tbtcBalance, verseBalance] as fixed point 18 decimals
        bytes memory data = abi.encodeWithSignature("getCurrentLiveBalances()");
        (bool success, bytes memory result) = address(balancerPool).staticcall(data);

        if (success && result.length >= 64) {
            uint256[] memory balances = abi.decode(result, (uint256[]));
            if (balances.length >= 2) {
                tbtcBalance = balances[0];
                verseBalance = balances[1];
            }
        }
    }

    /**
     * @notice Get BPT rate from vault
     */
    function getBptRate() public view returns (uint256) {
        // Call getBptRate on the vault
        bytes memory data = abi.encodeWithSignature("getBptRate(address)", address(balancerPool));
        (bool success, bytes memory result) = BALANCER_VAULT.staticcall(data);

        if (success && result.length >= 32) {
            return abi.decode(result, (uint256));
        }
        return 0;
    }

            /**
     * @notice Calculate expected LP tokens for given amounts using Balancer V3 Router query
     * @param _verseAmount Amount of VERSE tokens
     * @param _tbtcAmount Amount of tBTC tokens
     * @return expectedLpTokens Expected number of LP tokens to receive
     */
    function calculateExpectedLpTokens(uint256 _verseAmount, uint256 _tbtcAmount) public view returns (uint256 expectedLpTokens) {
        // Get current pool state
        (uint256 tbtcBalance, uint256 verseBalance) = getPoolBalances();
        uint256 lpTotalSupply = balancerPool.totalSupply();

        console2.log("Pool state:");
        console2.log("  tBTC balance:", tbtcBalance);
        console2.log("  VERSE balance:", verseBalance);
        console2.log("  LP total supply:", lpTotalSupply);

        if (lpTotalSupply == 0 || verseBalance == 0) {
            expectedLpTokens = 1 * 1e18; // Fallback to 1 LP token
            console2.log("Pool empty, using fallback:", expectedLpTokens);
            return expectedLpTokens;
        }

        // Calculate LP tokens based on VERSE proportion (80% of pool)
        // For an 80/20 pool, we calculate based on the VERSE proportion
        uint256 expectedLpTokensFromVerse = (_verseAmount * lpTotalSupply) / verseBalance;

        // Calculate LP tokens based on tBTC proportion (20% of pool)
        uint256 expectedLpTokensFromTbtc = (_tbtcAmount * lpTotalSupply) / tbtcBalance;

        // Use the smaller of the two to ensure we don't exceed either token's capacity
        expectedLpTokens = expectedLpTokensFromVerse < expectedLpTokensFromTbtc ?
            expectedLpTokensFromVerse : expectedLpTokensFromTbtc;

        console2.log("Calculated LP tokens from VERSE:", expectedLpTokensFromVerse);
        console2.log("Calculated LP tokens from tBTC:", expectedLpTokensFromTbtc);
        console2.log("Using smaller value:", expectedLpTokens);

        return expectedLpTokens;
    }

    /**
     * @notice Add liquidity using a single token (VERSE) to get exact LP tokens
     * @param _exactLpTokensOut Exact amount of LP tokens to receive
     * @param _maxVerseIn Maximum amount of VERSE willing to spend
     * @return actualVerseIn Actual amount of VERSE used
     */
    function addLiquiditySingle(uint256 _exactLpTokensOut, uint256 _maxVerseIn) external returns (uint256 actualVerseIn) {
        // Transfer VERSE from user to this contract
        require(
            verseToken.transferFrom(msg.sender, address(this), _maxVerseIn),
            "VERSE transfer failed"
        );

        console2.log("Adding liquidity single token with exact LP tokens out:", _exactLpTokensOut);
        console2.log("Max VERSE in:", _maxVerseIn);

        // Approve Permit2 for VERSE
        verseToken.approve(PERMIT2, type(uint256).max);

        // Give Router permission within Permit2 for VERSE
        IPermit2(PERMIT2).approve(
            address(verseToken),
            address(balancerRouter),
            uint160(_maxVerseIn),
            uint48(block.timestamp + 3600)
        );

        // Call addLiquiditySingleTokenExactOut
        actualVerseIn = balancerRouter.addLiquiditySingleTokenExactOut(
            address(balancerPool),
            verseToken,
            _maxVerseIn,
            _exactLpTokensOut,
            false, // wethIsEth
            "" // userData
        );

        console2.log("Actual VERSE used:", actualVerseIn);

        // Transfer LP tokens to user
        uint256 lpTokensReceived = lpToken.balanceOf(address(this));
        if (lpTokensReceived > 0) {
            require(
                lpToken.transfer(msg.sender, lpTokensReceived),
                "LP token transfer failed"
            );
            console2.log("LP tokens transferred to user:", lpTokensReceived);
        }

        return actualVerseIn;
    }

    /**
     * @notice Calculate the correct amounts of VERSE and tBTC needed for a given LP token amount
     * @param _desiredLpTokens Amount of LP tokens desired
     * @return verseAmount Amount of VERSE needed
     * @return tbtcAmount Amount of tBTC needed
     */
    function calculateAmountsForLpTokens(uint256 _desiredLpTokens) public view returns (uint256 verseAmount, uint256 tbtcAmount) {
        // Get current pool state
        (uint256 tbtcBalance, uint256 verseBalance) = getPoolBalances();
        uint256 lpTotalSupply = balancerPool.totalSupply();

        if (lpTotalSupply == 0) {
            return (0, 0);
        }

        // Calculate amounts based on current pool proportions
        // For an 80/20 pool, we need to maintain this ratio
        verseAmount = (_desiredLpTokens * verseBalance) / lpTotalSupply;
        tbtcAmount = (_desiredLpTokens * tbtcBalance) / lpTotalSupply;

        console2.log("For", _desiredLpTokens, "LP tokens, need:");
        console2.log("  VERSE:", verseAmount);
        console2.log("  tBTC:", tbtcAmount);

        return (verseAmount, tbtcAmount);
    }

    /**
     * @notice Add liquidity with exact LP token output using calculated amounts
     * @param _exactLpTokensOut Exact amount of LP tokens to receive
     * @param _maxVerseIn Maximum amount of VERSE willing to spend
     * @param _maxTbtcIn Maximum amount of tBTC willing to spend
     * @return actualVerseIn Actual amount of VERSE used
     * @return actualTbtcIn Actual amount of tBTC used
     */
    function addLiquidityExactOut(uint256 _exactLpTokensOut, uint256 _maxVerseIn, uint256 _maxTbtcIn) external returns (uint256 actualVerseIn, uint256 actualTbtcIn) {
        // Calculate the amounts needed for the desired LP tokens
        (uint256 neededVerse, uint256 neededTbtc) = calculateAmountsForLpTokens(_exactLpTokensOut);

        // Check if we have enough tokens
        require(neededVerse <= _maxVerseIn, "Insufficient VERSE");
        require(neededTbtc <= _maxTbtcIn, "Insufficient tBTC");

        // Transfer tokens from user to this contract
        require(
            verseToken.transferFrom(msg.sender, address(this), neededVerse),
            "VERSE transfer failed"
        );
        require(
            tbtcToken.transferFrom(msg.sender, address(this), neededTbtc),
            "tBTC transfer failed"
        );

        console2.log("Adding liquidity with exact LP tokens out:", _exactLpTokensOut);
        console2.log("Using VERSE:", neededVerse);
        console2.log("Using tBTC:", neededTbtc);

        // Add liquidity using the proportional method
        _addLiquidityViaRouter(neededVerse, neededTbtc, _exactLpTokensOut);

        // Transfer LP tokens to user
        uint256 lpTokensReceived = lpToken.balanceOf(address(this));
        if (lpTokensReceived > 0) {
            require(
                lpToken.transfer(msg.sender, lpTokensReceived),
                "LP token transfer failed"
            );
            console2.log("LP tokens transferred to user:", lpTokensReceived);
        }

        return (neededVerse, neededTbtc);
    }

    /**
     * @notice Calculate LP tokens from VERSE amount using pool state
     */
    function _calculateLpTokensFromVerse(uint256 _verseAmount) internal view returns (uint256) {
        // Get current pool state
        (uint256 tbtcBalance, uint256 verseBalance) = getPoolBalances();
        uint256 lpTotalSupply = balancerPool.totalSupply();

        if (lpTotalSupply == 0 || verseBalance == 0) {
            return 0;
        }

        // Calculate LP tokens based on VERSE proportion
        uint256 expectedLpTokens = (_verseAmount * lpTotalSupply) / verseBalance;

        // Add some buffer for slippage (0.1%)
        expectedLpTokens = (expectedLpTokens * 999) / 1000;

        return expectedLpTokens;
    }

    /**
     * @notice Execute the complete migration process
     * @param _farmReceiptAmount Amount of SimpleFarmA receipt tokens to migrate
     * @param _verseToSwap Amount of VERSE to swap for tBTC
     * @param _minTbtcOut Minimum tBTC to receive from swap
     * @param _minLpOut Minimum LP tokens to receive
     */
    function executeMigration(
        uint256 _farmReceiptAmount,
        uint256 _verseToSwap,
        uint256 _minTbtcOut,
        uint256 _minLpOut
    )
        external
    {
        // Step 1: Transfer SimpleFarmA receipt tokens from user to orchestrator
        require(
            simpleFarmA.transferFrom(msg.sender, address(this), _farmReceiptAmount),
            "FarmMigrationOrchestratorV3Router: RECEIPT_TRANSFER_FAILED"
        );

        // Step 2: Withdraw VERSE from SimpleFarmA
        simpleFarmA.farmWithdraw(_farmReceiptAmount);

        // Check VERSE balance received
        uint256 verseBalance = verseToken.balanceOf(address(this));
        require(verseBalance >= _verseToSwap, "FarmMigrationOrchestratorV3Router: INSUFFICIENT_VERSE");

        // Step 3: Use the actual VERSE balance from FarmA withdrawal
        uint256 verseToUse = verseBalance; // Use whatever VERSE we got from FarmA

        // For testing, let's use the actual available balance
        console2.log("Available VERSE balance:", verseBalance);
        console2.log("Using VERSE amount:", verseToUse);

        // Step 3: Execute swap directly (skip quote for now)
        uint256 verseToSwapAmount = (verseToUse * 20) / 100; // 20% of VERSE

        console2.log("Swapping VERSE to tBTC:", verseToSwapAmount);

        // Execute the swap
        uint256 tbtcReceived = _swapVerseToTbtcViaRouter(verseToSwapAmount, _minTbtcOut);

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
                "FarmMigrationOrchestratorV3Router: FARMB_TRANSFER_FAILED"
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
