// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./IERC20.sol";
import "./SafeERC20.sol";
import "./IBalancerV3Router.sol";
import "./IPermit2.sol";
import "./ISimpleFarm.sol";
import "./IBalancerV3Pool.sol";

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

    event LiquidityAdded(
        address indexed user,
        uint256 verseAmountIn,
        uint256 tbtcAmountIn,
        uint256 lpTokensOut,
        uint256 exactBptAmountOut
    );

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
        verseToken.approve(
            PERMIT2,
            type(uint256).max
        );

        IPermit2(PERMIT2).approve(
            address(verseToken),
            address(balancerRouter),
            uint160(_verseAmount),
            uint48(_deadline)
        );

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
        tbtcToken.approve(
            PERMIT2,
            type(uint256).max
        );

        IPermit2(PERMIT2).approve(
            address(tbtcToken),
            address(balancerRouter),
            uint160(_tbtcAmount),
            uint48(_deadline)
        );

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
        verseToken.approve(
            PERMIT2,
            type(uint256).max
        );

        tbtcToken.approve(
            PERMIT2,
            type(uint256).max
        );

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

        uint256[] memory amountsIn = balancerRouter.addLiquidityProportional(
            address(balancerPool),
            maxAmountsIn,
            _exactBptAmountOut,
            false, // wethIsEth
            "" // userData
        );

        uint256 bptAmountOut = lpToken.balanceOf(
            address(this)
        );

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
     * @notice Internal function for adding liquidity
     * @dev Assumes tokens are already in this contract
     */
    function _addLiquidity(
        uint256 _verseAmount,
        uint256 _tbtcAmount,
        uint256 _deadline
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
            _deadline
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
        verseToken.transferFrom(
            msg.sender,
            address(this),
            _verseAmount
        );

        tbtcToken.transferFrom(
            msg.sender,
            address(this),
            _tbtcAmount
        );

        // Add liquidity with specified exactBptAmountOut or auto-calculate if 0
        uint256 exactBptAmountOut = _exactBptAmountOut == 0
            ? calculateExpectedLpTokens(
                _verseAmount,
                _tbtcAmount
            )
            : _exactBptAmountOut;

        // Validate deadline
        require(
            block.timestamp <= _deadline,
            "FarmMigrationOrchestratorV3Router: DEADLINE_EXPIRED"
        );

        uint256 lpTokensReceived = _addLiquidityViaRouter(
            _verseAmount,
            _tbtcAmount,
            exactBptAmountOut,
            _deadline
        );

        // Check orchestrator balances after liquidity addition
        uint256 orchestratorVerseBalance = verseToken.balanceOf(address(this));
        uint256 orchestratorTbtcBalance = tbtcToken.balanceOf(address(this));

        // Transfer LP tokens back to user
        if (lpTokensReceived > 0) {
            lpToken.transfer(
                msg.sender,
                lpTokensReceived
            );
        }

        // Return any remaining tokens to user
        if (orchestratorVerseBalance > 0) {
            verseToken.transfer(
                msg.sender,
                orchestratorVerseBalance
            );
        }

        if (orchestratorTbtcBalance > 0) {
            tbtcToken.transfer(
                msg.sender,
                orchestratorTbtcBalance
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
        verseToken.transferFrom(
            msg.sender,
            address(this),
            _verseAmount
        );

        tbtcToken.transferFrom(
            msg.sender,
            address(this),
            _tbtcAmount
        );

        uint256 exactBptAmountOut = calculateExpectedLpTokens(
            _verseAmount,
            _tbtcAmount
        );

        uint256 slippageAdjustedBpt = (
            exactBptAmountOut * (10000 - _slippageBps)
        ) / 10000;

        uint256 lpTokensReceived = _addLiquidityViaRouter(
            _verseAmount,
            _tbtcAmount,
            slippageAdjustedBpt,
            _deadline
        );

        uint256 orchestratorVerseBalance = verseToken.balanceOf(
            address(this)
        );

        uint256 orchestratorTbtcBalance = tbtcToken.balanceOf(
            address(this)
        );

        if (lpTokensReceived > 0) {

            lpToken.approve(
                address(simpleFarmB),
                lpTokensReceived
            );

            simpleFarmB.farmDeposit(
                lpTokensReceived
            );

            farmBReceipts = simpleFarmB.balanceOf(
                address(this)
            );

            if (farmBReceipts > 0) {
                simpleFarmB.transfer(
                    msg.sender,
                    farmBReceipts
                );
            }
        }

        // Return any remaining tokens to user
        if (orchestratorVerseBalance > 0) {
            verseToken.transfer(
                msg.sender,
                orchestratorVerseBalance
            );
        }

        if (orchestratorTbtcBalance > 0) {
            tbtcToken.transfer(
                msg.sender,
                orchestratorTbtcBalance
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
        require(
            block.timestamp <= _deadline,
            "FarmMigrationOrchestratorV3Router: DEADLINE_EXPIRED"
        );

        // Validate input token
        require(
            _tokenIn == address(verseToken) || _tokenIn == address(tbtcToken),
            "Invalid input token - must be VERSE or tBTC"
        );

        bool isVerseInput = _tokenIn == address(
            verseToken
        );

        IERC20 tokenIn = IERC20(
            _tokenIn
        );

        tokenIn.transferFrom(
            msg.sender,
            address(this),
            _amountIn
        );

        uint256 verseForLiquidity;
        uint256 tbtcForLiquidity;

        if (isVerseInput) {
            // VERSE input: swap 20% to tBTC for 80/20 ratio
            uint256 verseToSwap = (_amountIn * 20) / 100; // 20% of VERSE
            verseForLiquidity = _amountIn - verseToSwap; // 80% of VERSE

            // Swap VERSE to tBTC
            tbtcForLiquidity = _swapVerseToTbtcViaRouter(
                verseToSwap,
                0, // minTbtcOut - no minimum for ZAP
                _deadline
            );
        } else {
            // tBTC input: swap 80% to VERSE for 80/20 ratio
            uint256 tbtcToSwap = (_amountIn * 80) / 100; // 80% of tBTC
            tbtcForLiquidity = _amountIn - tbtcToSwap; // 20% of tBTC

            // Swap tBTC to VERSE using the proper swap function
            verseForLiquidity = _swapTbtcToVerseViaRouter(
                tbtcToSwap,
                0, // minVerseOut - no minimum for ZAP
                _deadline
            );
        }

        uint256 exactBptAmountOut = calculateExpectedLpTokens(
            verseForLiquidity,
            tbtcForLiquidity
        );

        uint256 slippageAdjustedBpt = (
            exactBptAmountOut * (10000 - _slippageBps)
        ) / 10000;

        uint256 lpTokensReceived = _addLiquidityViaRouter(
            verseForLiquidity,
            tbtcForLiquidity,
            slippageAdjustedBpt,
            _deadline
        );

        // Check orchestrator balances after liquidity addition
        uint256 orchestratorVerseBalance = verseToken.balanceOf(
            address(this)
        );

        uint256 orchestratorTbtcBalance = tbtcToken.balanceOf(
            address(this)
        );

        if (lpTokensReceived > 0) {
            lpToken.approve(
                address(simpleFarmB),
                lpTokensReceived
            );

            simpleFarmB.farmDeposit(
                lpTokensReceived
            );

            farmBReceipts = simpleFarmB.balanceOf(
                address(this)
            );

            // Transfer FarmB receipt tokens to user
            if (farmBReceipts > 0) {
                simpleFarmB.transfer(
                    msg.sender,
                    farmBReceipts
                );
            }
        }

        // Return any remaining tokens to user
        if (orchestratorVerseBalance > 0) {
            verseToken.transfer(
                msg.sender,
                orchestratorVerseBalance
            );
        }

        if (orchestratorTbtcBalance > 0) {
            tbtcToken.transfer(
                msg.sender,
                orchestratorTbtcBalance
            );
        }

        return farmBReceipts;
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
        (
            uint256 tbtcBalance,
            uint256 verseBalance
        ) = getPoolBalances();

        uint256 lpTotalSupply = balancerPool.totalSupply();

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

        return expectedLpTokens;
    }

    /**
     * @notice Get current pool balances
     */
    function getPoolBalances()
        public
        view
        returns (
            uint256 tbtcBalance,
            uint256 verseBalance
        )
    {
        bytes memory data = abi.encodeWithSignature(
            "getCurrentLiveBalances()"
        );

        (
            bool success,
            bytes memory result
        ) = address(balancerPool).staticcall(data);

        if (success && result.length >= 64) {
            uint256[] memory balances = abi.decode(
                result,
                (uint256[])
            );
            if (balances.length >= 2) {
                tbtcBalance = balances[0];
                verseBalance = balances[1];
            }
        }
    }
}
