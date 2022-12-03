// SPDX-License-Identifier: BCOM

pragma solidity ^0.8.0;

interface IERC20 {

    function balanceOf(
        address account
    )
        external
        view
        returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    )
        external
        returns (bool);
}

library SafeERC20 {

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    )
        internal
    {
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    )
        internal
    {
    }
}

contract Ownable {

    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(
            _owner == msg.sender,
            "Ownable: caller is not the owner"
        );
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     */
    function renounceOwnership()
        public
        onlyOwner
    {
        emit OwnershipTransferred(
            _owner,
            address(0)
        );

        _owner = address(0);
    }

    function transferOwnership(
        address newOwner
    )
        public
        onlyOwner
    {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );

        emit OwnershipTransferred(
            _owner,
            newOwner
        );

        _owner = newOwner;
    }
}

contract MasterStaking is Ownable {

    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SUSHIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSushiPerShare) - user.rewardDebt
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
    }

    IERC20 public sushi;

    // SUSHI tokens created per block.
    uint256 public sushiPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    event Deposit(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    constructor(
        IERC20 _sushi,
        uint256 _sushiPerBlock
    ) {
        sushi = _sushi;
        sushiPerBlock = _sushiPerBlock;
    }

    function poolLength()
        external
        view
        returns (uint256)
    {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    // FORCE THE CHECK ON THIS ACTION! 1 LP TOKEN ONLY ONE FARM
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint256 _startBlock
    )
        external
        onlyOwner
    {
        uint256 startingBlock = block.number > _startBlock
            ? block.number
            : _startBlock;

        totalAllocPoint = totalAllocPoint
            + _allocPoint;

        poolInfo.push(
            PoolInfo(
                {
                    lpToken: _lpToken,
                    allocPoint: _allocPoint,
                    lastRewardBlock: startingBlock,
                    accSushiPerShare: 0
                }
            )
        );
    }

    function set(
        uint256 _poolId,
        uint256 _allocPoint
    )
        external
        onlyOwner
    {
        totalAllocPoint = totalAllocPoint
            - poolInfo[_poolId].allocPoint
            + _allocPoint;

        poolInfo[_poolId].allocPoint = _allocPoint;
    }

    // View function to see pending SUSHIs on frontend.
    function pendingSushi(
        uint256 _poolId,
        address _user
    )
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[_poolId][_user];

        uint256 accSushiPerShare = pool.accSushiPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {


            uint256 sushiReward = sushiPerBlock
                * pool.allocPoint
                / totalAllocPoint;

            accSushiPerShare = accSushiPerShare + (sushiReward * 1e12 / lpSupply);
        }

        return user.amount
            * accSushiPerShare
            / 1e12
            - user.rewardDebt;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools()
        external
    {
        uint256 length = poolInfo.length;
        for (uint256 poolId = 0; poolId < length; ++poolId) {
            updatePool(poolId);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(
        uint256 _poolId
    )
        public
    {
        PoolInfo storage pool = poolInfo[_poolId];

        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = pool.lpToken.balanceOf(
            address(this)
        );

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 sushiReward = sushiPerBlock
            * pool.allocPoint
            / totalAllocPoint;

        sushi.transfer(
            address(this),
            sushiReward
        );

        pool.accSushiPerShare += sushiReward
            * 1e12
            / lpSupply;

        pool.lastRewardBlock = block.number;
    }

    function deposit(
        uint256 _poolId,
        uint256 _amount
    )
        external
    {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];

        updatePool(
            _poolId
        );

        if (user.amount > 0) {

            uint256 pending = user.amount
                * pool.accSushiPerShare
                / 1e12
                - user.rewardDebt;

            sushi.transfer(
                msg.sender,
                pending
            );
        }

        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );

        user.amount =
        user.amount + _amount;

        user.rewardDebt = user.amount
            * pool.accSushiPerShare
            / 1e12;

        emit Deposit(
            msg.sender,
            _poolId,
            _amount
        );
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(
        uint256 _poolId,
        uint256 _amount
    )
        external
    {
        PoolInfo storage pool = poolInfo[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];

        updatePool(
            _poolId
        );

        user.amount =
        user.amount - _amount;

        uint256 pending = user.amount
            * pool.accSushiPerShare
            / 1e12
            - user.rewardDebt;


        sushi.transfer(
            msg.sender,
            pending
        );

        user.rewardDebt = user.amount
            * pool.accSushiPerShare
            / 1e12;

        pool.lpToken.safeTransfer(
            address(msg.sender),
            _amount
        );

        emit Withdraw(
            msg.sender,
            _poolId,
            _amount
        );
    }
}
