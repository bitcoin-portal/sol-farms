// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./IBalancerV3Router.sol";
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

    event LiquidityAdded(
        address indexed user,
        uint256 verseAmountIn,
        uint256 tbtcAmountIn,
        uint256 lpTokensOut,
        uint256 exactBptAmountOut
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
        uint256 _minTbtcOut,
        uint256 _deadline
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
            uint48(_deadline)
        );

        // Execute swap using swapSingleTokenExactIn
        uint256 amountOut = balancerRouter.swapSingleTokenExactIn(
            address(balancerPool),
            verseToken,
            tbtcToken,
            _verseAmount,
            _minTbtcOut,
            _deadline,
            false, // wethIsEth
            "" // userData
        );

        return amountOut;
    }

    /**
     * @notice Swap tBTC tokens to VERSE via Balancer V3 Router
     * @param _tbtcAmount Amount of tBTC tokens to swap
     * @param _minVerseOut Minimum amount of VERSE to receive
     * @param _deadline Transaction deadline
     * @return amountOut Amount of VERSE received
     */
    function _swapTbtcToVerseViaRouter(
        uint256 _tbtcAmount,
        uint256 _minVerseOut,
        uint256 _deadline
    )
        internal
        returns (uint256)
    {
        // Always approve Permit2 with max amount to avoid allowance issues
        tbtcToken.approve(
            PERMIT2,
            type(uint256).max
        );

        // Give Router permission within Permit2
        IPermit2(PERMIT2).approve(
            address(tbtcToken),
            address(balancerRouter),
            uint160(_tbtcAmount),
            uint48(_deadline)
        );

        // Execute swap using swapSingleTokenExactIn
        uint256 amountOut = balancerRouter.swapSingleTokenExactIn(
            address(balancerPool),
            tbtcToken,
            verseToken,
            _tbtcAmount,
            _minVerseOut,
            _deadline,
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
        uint256 _exactBptAmountOut,
        uint256 _deadline
    )
        internal
        returns (uint256)
    {
        // Always approve Permit2 with max amounts
        verseToken.approve(
            PERMIT2,
            type(uint256).max
        );

        tbtcToken.approve(
            PERMIT2,
            type(uint256).max
        );

        // Give Router permission within Permit2 for both tokens
        IPermit2(PERMIT2).approve(
            address(verseToken),
            address(balancerRouter),
            uint160(_verseAmount),
            uint48(_deadline)
        );

        IPermit2(PERMIT2).approve(
            address(tbtcToken),
            address(balancerRouter),
            uint160(_tbtcAmount),
            uint48(_deadline)
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

        // Determine the actual amounts used for each token based on pool token order
        uint256 actualVerseAmount;
        uint256 actualTbtcAmount;

        if (poolTokens[0] == address(verseToken)) {
            // VERSE is first in pool, tBTC is second
            actualVerseAmount = amountsIn[0];
            actualTbtcAmount = amountsIn[1];
        } else {
            // tBTC is first in pool, VERSE is second
            actualVerseAmount = amountsIn[1];
            actualTbtcAmount = amountsIn[0];
        }

        console2.log("Actual amounts used for liquidity:");
        console2.log("  VERSE used:", actualVerseAmount);
        console2.log("  tBTC used:", actualTbtcAmount);
        console2.log("  LP tokens received:", bptAmountOut);

        // Emit event with the actual amounts used and LP tokens received
        emit LiquidityAdded(
            msg.sender,
            actualVerseAmount,
            actualTbtcAmount,
            bptAmountOut,
            _exactBptAmountOut
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
            expectedLpTokens,
            block.timestamp + 3600 // Default deadline for internal calls
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
        uint256 _exactBptAmountOut,
        uint256 _deadline
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
        uint256 exactBptAmountOut = _exactBptAmountOut == 0
            ? calculateExpectedLpTokens(_verseAmount, _tbtcAmount)
            : _exactBptAmountOut;

        // Validate deadline
        require(block.timestamp <= _deadline, "FarmMigrationOrchestratorV3Router: DEADLINE_EXPIRED");

        uint256 lpTokensReceived = _addLiquidityViaRouter(
            _verseAmount,
            _tbtcAmount,
            exactBptAmountOut,
            _deadline
        );

        // Check orchestrator balances after liquidity addition
        uint256 orchestratorVerseBalance = verseToken.balanceOf(address(this));
        uint256 orchestratorTbtcBalance = tbtcToken.balanceOf(address(this));
        console2.log("Orchestrator balances after liquidity addition:");
        console2.log("  VERSE remaining:", orchestratorVerseBalance);
        console2.log("  tBTC remaining:", orchestratorTbtcBalance);

        // Transfer LP tokens back to user
        if (lpTokensReceived > 0) {
            require(
                lpToken.transfer(msg.sender, lpTokensReceived),
                "LP token transfer failed"
            );
        }

        // Return any remaining tokens to user
        if (orchestratorVerseBalance > 0) {
            console2.log("Returning remaining VERSE to user:", orchestratorVerseBalance);
            require(
                verseToken.transfer(msg.sender, orchestratorVerseBalance),
                "VERSE return transfer failed"
            );
        }

        if (orchestratorTbtcBalance > 0) {
            console2.log("Returning remaining tBTC to user:", orchestratorTbtcBalance);
            require(
                tbtcToken.transfer(msg.sender, orchestratorTbtcBalance),
                "tBTC return transfer failed"
            );
        }

        return lpTokensReceived;
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
        uint256 _slippageBps,
        uint256 _deadline
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

        // Validate deadline
        require(block.timestamp <= _deadline, "FarmMigrationOrchestratorV3Router: DEADLINE_EXPIRED");

        uint256 lpTokensReceived = _addLiquidityViaRouter(
            _verseAmount,
            _tbtcAmount,
            slippageAdjustedBpt,
            _deadline
        );

        console2.log("LP tokens received from addLiquidity:", lpTokensReceived);

        // Check orchestrator balances after liquidity addition
        uint256 orchestratorVerseBalance = verseToken.balanceOf(address(this));
        uint256 orchestratorTbtcBalance = tbtcToken.balanceOf(address(this));
        console2.log("Orchestrator balances after liquidity addition:");
        console2.log("  VERSE remaining:", orchestratorVerseBalance);
        console2.log("  tBTC remaining:", orchestratorTbtcBalance);

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

        // Return any remaining tokens to user
        if (orchestratorVerseBalance > 0) {
            console2.log("Returning remaining VERSE to user:", orchestratorVerseBalance);
            require(
                verseToken.transfer(msg.sender, orchestratorVerseBalance),
                "VERSE return transfer failed"
            );
        }

        if (orchestratorTbtcBalance > 0) {
            console2.log("Returning remaining tBTC to user:", orchestratorTbtcBalance);
            require(
                tbtcToken.transfer(msg.sender, orchestratorTbtcBalance),
                "tBTC return transfer failed"
            );
        }

        return farmBReceipts;
    }

    /**
     * @notice Universal ZAP function: Add liquidity and stake using either VERSE or tBTC tokens
     * @dev Automatically swaps the necessary amount to maintain 80/20 ratio, then adds liquidity and stakes
     * @param _tokenIn Address of the input token (VERSE or tBTC)
     * @param _amountIn Amount of input tokens to use
     * @param _slippageBps Slippage tolerance in basis points (e.g., 1000 = 10%)
     * @param _deadline Transaction deadline
     * @return farmBReceipts Amount of FarmB receipt tokens received
     */
    function zapToFarmB(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _slippageBps,
        uint256 _deadline
    )
        external
        returns (uint256 farmBReceipts)
    {
        // Validate deadline
        require(block.timestamp <= _deadline, "FarmMigrationOrchestratorV3Router: DEADLINE_EXPIRED");

        // Validate input token
        require(
            _tokenIn == address(verseToken) || _tokenIn == address(tbtcToken),
            "Invalid input token - must be VERSE or tBTC"
        );

        bool isVerseInput = _tokenIn == address(verseToken);
        IERC20 tokenIn = IERC20(_tokenIn);

        // Transfer tokens from user to this contract
        require(
            tokenIn.transferFrom(msg.sender, address(this), _amountIn),
            "Token transfer failed"
        );

        console2.log("ZAP: Received", _amountIn, isVerseInput ? "VERSE" : "tBTC", "tokens");

        uint256 verseForLiquidity;
        uint256 tbtcForLiquidity;

        if (isVerseInput) {
            // VERSE input: swap 20% to tBTC for 80/20 ratio
            uint256 verseToSwap = (_amountIn * 20) / 100; // 20% of VERSE
            verseForLiquidity = _amountIn - verseToSwap; // 80% of VERSE

            console2.log("ZAP: Swapping", verseToSwap, "VERSE to tBTC");
            console2.log("ZAP: Using", verseForLiquidity, "VERSE for liquidity");

            // Swap VERSE to tBTC
            tbtcForLiquidity = _swapVerseToTbtcViaRouter(
                verseToSwap,
                0, // minTbtcOut - no minimum for ZAP
                _deadline
            );

            console2.log("ZAP: Received", tbtcForLiquidity, "tBTC from swap");
                } else {
            // tBTC input: swap 80% to VERSE for 80/20 ratio
            uint256 tbtcToSwap = (_amountIn * 80) / 100; // 80% of tBTC
            tbtcForLiquidity = _amountIn - tbtcToSwap; // 20% of tBTC

            console2.log("ZAP: Swapping", tbtcToSwap, "tBTC to VERSE");
            console2.log("ZAP: Using", tbtcForLiquidity, "tBTC for liquidity");

            // Swap tBTC to VERSE using the proper swap function
            verseForLiquidity = _swapTbtcToVerseViaRouter(
                tbtcToSwap,
                0, // minVerseOut - no minimum for ZAP
                _deadline
            );

            console2.log("ZAP: Received", verseForLiquidity, "VERSE from swap");
        }

        // Calculate expected LP tokens for the liquidity addition
        uint256 exactBptAmountOut = calculateExpectedLpTokens(
            verseForLiquidity,
            tbtcForLiquidity
        );

        // Apply slippage tolerance
        uint256 slippageAdjustedBpt = (exactBptAmountOut * (10000 - _slippageBps)) / 10000;
        console2.log("ZAP: Original exactBptAmountOut:", exactBptAmountOut);
        console2.log("ZAP: Slippage adjusted BPT:", slippageAdjustedBpt);

        // Add liquidity using the proportional method
        uint256 lpTokensReceived = _addLiquidityViaRouter(
            verseForLiquidity,
            tbtcForLiquidity,
            slippageAdjustedBpt,
            _deadline
        );

        console2.log("ZAP: LP tokens received from addLiquidity:", lpTokensReceived);

        // Check orchestrator balances after liquidity addition
        uint256 orchestratorVerseBalance = verseToken.balanceOf(address(this));
        uint256 orchestratorTbtcBalance = tbtcToken.balanceOf(address(this));
        console2.log("ZAP: Orchestrator balances after liquidity addition:");
        console2.log("  VERSE remaining:", orchestratorVerseBalance);
        console2.log("  tBTC remaining:", orchestratorTbtcBalance);

        // Stake LP tokens in FarmB if we received any
        if (lpTokensReceived > 0) {
            // Approve FarmB to spend LP tokens
            lpToken.approve(address(simpleFarmB), lpTokensReceived);

            // Stake LP tokens in FarmB
            simpleFarmB.farmDeposit(lpTokensReceived);

            // Get FarmB receipt tokens
            farmBReceipts = simpleFarmB.balanceOf(address(this));

            console2.log("ZAP: FarmB receipt tokens received:", farmBReceipts);

            // Transfer FarmB receipt tokens to user
            if (farmBReceipts > 0) {
                require(
                    simpleFarmB.transfer(msg.sender, farmBReceipts),
                    "FarmB receipt transfer failed"
                );
            }
        }

        // Return any remaining tokens to user
        if (orchestratorVerseBalance > 0) {
            console2.log("ZAP: Returning remaining VERSE to user:", orchestratorVerseBalance);
            require(
                verseToken.transfer(msg.sender, orchestratorVerseBalance),
                "VERSE return transfer failed"
            );
        }

        if (orchestratorTbtcBalance > 0) {
            console2.log("ZAP: Returning remaining tBTC to user:", orchestratorTbtcBalance);
            require(
                tbtcToken.transfer(msg.sender, orchestratorTbtcBalance),
                "tBTC return transfer failed"
            );
        }

        return farmBReceipts;
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
     * @notice Calculate expected LP tokens for given amounts using Balancer V3 Router query
     * @param _verseAmount Amount of VERSE tokens
     * @param _tbtcAmount Amount of tBTC tokens
     * @return expectedLpTokens Expected number of LP tokens to receive
     */
    function calculateExpectedLpTokens(
        uint256 _verseAmount,
        uint256 _tbtcAmount
    )
        public
        view
        returns (uint256 expectedLpTokens)
    {
        // Use manual calculation - router query is not suitable for our use case
        // Router query tells us "how much tokens needed for X LP tokens"
        // But we want "how much LP tokens for X token amounts"
        console2.log("Using manual calculation for LP token estimation");

        // Get current pool state
        (uint256 tbtcBalance, uint256 verseBalance) = getPoolBalances();
        uint256 lpTotalSupply = balancerPool.totalSupply();

        if (lpTotalSupply == 0 || verseBalance == 0) {
            expectedLpTokens = 1 * 1e18; // Fallback to 1 LP token
            console2.log("Pool empty, using fallback:", expectedLpTokens);
            return expectedLpTokens;
        }

        // Calculate LP tokens based on VERSE proportion (80% of pool)
        uint256 expectedLpTokensFromVerse = _verseAmount
            * lpTotalSupply
            / verseBalance;

        // Calculate LP tokens based on tBTC proportion (20% of pool)
        uint256 expectedLpTokensFromTbtc = _tbtcAmount
            * lpTotalSupply
            / tbtcBalance;

        // Use the smaller of the two to ensure we don't exceed either token's capacity
        expectedLpTokens = expectedLpTokensFromVerse < expectedLpTokensFromTbtc
            ? expectedLpTokensFromVerse
            : expectedLpTokensFromTbtc;

        console2.log("Manual calculation - LP tokens from VERSE:", expectedLpTokensFromVerse);
        console2.log("Manual calculation - LP tokens from tBTC:", expectedLpTokensFromTbtc);
        console2.log("Manual calculation - using smaller value:", expectedLpTokens);

        return expectedLpTokens;
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

        // Validate deadline
        require(block.timestamp <= _deadline, "FarmMigrationOrchestratorV3Router: DEADLINE_EXPIRED");

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
