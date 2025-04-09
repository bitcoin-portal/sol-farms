// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Minimal ERC20 interface with only required functions
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router02 {
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IUniswapV2Pair {
    function balanceOf(address owner) external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
    function totalSupply() external view returns (uint256);
}

interface IBalancerRouter {
    enum AddLiquidityKind {
        PROPORTIONAL,
        SINGLE_TOKEN,
        UNBALANCED,
        CUSTOM
    }

    struct AddLiquidityHookParams {
        address sender;
        address pool;
        uint256[] maxAmountsIn;
        uint256 minBptAmountOut;
        AddLiquidityKind kind;
        bool wethIsEth;
        bytes userData;
    }

    function addLiquidityUnbalanced(
        address pool,
        uint256[] memory exactAmountsIn,
        uint256 minBptAmountOut,
        bool wethIsEth,
        bytes memory userData
    ) external returns (uint256[] memory amountsIn);

    function addLiquidityHook(
        AddLiquidityHookParams memory params
    ) external returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData);
}

contract LiquidityMigrator {
    // Ownership management
    address public owner;

    // Modifier for owner-only functions
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // Router and external contract interfaces
    IUniswapV2Router02 public uniswapV2Router;
    IBalancerRouter public balancerRouter;

    // Transfer ownership event
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(
        address _uniswapV2RouterAddress,
        address _balancerRouterAddress
    ) {
        owner = msg.sender;
        uniswapV2Router = IUniswapV2Router02(_uniswapV2RouterAddress);
        balancerRouter = IBalancerRouter(_balancerRouterAddress);
    }

    // Ownership transfer function
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function migrateLiquidity(
        address _v2Pool,
        address _primaryToken,
        address _secondaryToken,
        address _balancerPool
    ) external {
        // 1. Transfer and remove V2 LP tokens
        IERC20 v2LpToken = IERC20(_v2Pool);
        uint256 lpTokenAmount = v2LpToken.balanceOf(msg.sender);
        require(lpTokenAmount > 0, "No LP tokens to migrate");

        v2LpToken.transferFrom(msg.sender, address(this), lpTokenAmount);
        v2LpToken.approve(address(uniswapV2Router), lpTokenAmount);

        // 2. Remove liquidity from Uniswap V2
        (uint256 amount0, uint256 amount1) = uniswapV2Router.removeLiquidity(
            _primaryToken,
            _secondaryToken,
            lpTokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        // 3. Approve tokens for Balancer Router
        IERC20(_primaryToken).approve(address(balancerRouter), amount0);
        IERC20(_secondaryToken).approve(address(balancerRouter), amount1);

        // 4. Prepare amounts for Balancer pool
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        // 5. Add liquidity to Balancer pool using unbalanced method
        uint256[] memory actualAmountsIn = balancerRouter.addLiquidityUnbalanced(
            _balancerPool,
            amounts,
            0, // minBptAmountOut (set to 0 for this example)
            false, // wethIsEth
            new bytes(0) // optional user data
        );

        // 6. Return any leftover tokens
        _returnRemainingTokens(
            _primaryToken,
            _secondaryToken,
            amount0,
            amount1,
            actualAmountsIn[0],
            actualAmountsIn[1]
        );

        emit LiquidityMigrated(
            msg.sender,
            _v2Pool,
            _balancerPool,
            actualAmountsIn[0],
            actualAmountsIn[1]
        );
    }

    function _returnRemainingTokens(
        address _primaryToken,
        address _secondaryToken,
        uint256 totalAmount0,
        uint256 totalAmount1,
        uint256 usedAmount0,
        uint256 usedAmount1
    ) internal {
        uint256 remainingPrimary = totalAmount0 - usedAmount0;
        uint256 remainingSecondary = totalAmount1 - usedAmount1;

        if (remainingPrimary > 0) {
            IERC20(_primaryToken).transfer(msg.sender, remainingPrimary);
        }

        if (remainingSecondary > 0) {
            IERC20(_secondaryToken).transfer(msg.sender, remainingSecondary);
        }
    }

    function rescueTokens(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner, _amount);
    }

    function estimateMigration(
        address _user,
        address _v2Pool,
        address _primaryToken
    ) external view returns (MigrationDetails memory migrationDetails) {
        IUniswapV2Pair pair = IUniswapV2Pair(_v2Pool);
        uint256 lpTokenBalance = pair.balanceOf(_user);
        migrationDetails.lpTokenBalance = lpTokenBalance;

        if (lpTokenBalance == 0) {
            return migrationDetails;
        }

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();

        address token0 = pair.token0();
        address token1 = pair.token1();

        uint256 totalSupply = pair.totalSupply();
        uint256 amount0 = lpTokenBalance * reserve0 / totalSupply;
        uint256 amount1 = lpTokenBalance * reserve1 / totalSupply;

        bool isPrimaryToken0 = _primaryToken == token0;
        uint256 primaryAmount = isPrimaryToken0 ? amount0 : amount1;
        uint256 secondaryAmount = isPrimaryToken0 ? amount1 : amount0;

        migrationDetails.token0 = token0;
        migrationDetails.token1 = token1;
        migrationDetails.primaryTokenAmount = primaryAmount;
        migrationDetails.secondaryTokenAmount = secondaryAmount;
        migrationDetails.primaryTokenToAdd = primaryAmount;
        migrationDetails.secondaryTokenToAdd = secondaryAmount;
        migrationDetails.primaryTokenLeftover = 0;
        migrationDetails.secondaryTokenLeftover = 0;

        return migrationDetails;
    }

    struct MigrationDetails {
        uint256 lpTokenBalance;
        address token0;
        address token1;
        uint256 primaryTokenAmount;
        uint256 secondaryTokenAmount;
        uint256 primaryTokenToAdd;
        uint256 secondaryTokenToAdd;
        uint256 primaryTokenLeftover;
        uint256 secondaryTokenLeftover;
    }

    event LiquidityMigrated(
        address indexed user,
        address indexed v2Pool,
        address indexed balancerPool,
        uint256 primaryAmount,
        uint256 secondaryAmount
    );

    receive() external payable {}
}