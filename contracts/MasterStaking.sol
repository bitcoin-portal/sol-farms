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

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        returns (bool);
}

contract SafeERC20 {

    function safeTransfer(
        IERC20 _token,
        address _to,
        uint256 _value
    )
        internal
    {
        callOptionalReturn(
            _token,
            abi.encodeWithSelector(
                _token.transfer.selector,
                _to,
                _value
            )
        );
    }

    function safeTransferFrom(
        IERC20 _token,
        address _from,
        address _to,
        uint256 _value
    )
        internal
    {
        callOptionalReturn(
            _token,
            abi.encodeWithSelector(
                _token.transferFrom.selector,
                _from,
                _to,
                _value
            )
        );
    }

    function callOptionalReturn(
        IERC20 _token,
        bytes memory _data
    )
        private
    {
        (
            bool success,
            bytes memory returndata
        ) = address(_token).call(_data);

        require(
            success,
            "SafeERC20: CALL_FAILED"
        );

        if (returndata.length > 0) {
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: OPERATION_FAILED"
            );
        }
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

contract MasterStaking is Ownable, SafeERC20 {

    // Info of each user.
    struct UserInfo {
        uint256 depositAmount;     // How many LP tokens the user has provided.
        uint256 rewardIssued; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SUSHIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSushiPerShare) - user.rewardDebt
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 rewardPoints;       // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
        IERC20 stakeToken;
        IERC20 rewardToken;
    }

    IERC20 public sushi;

    // SUSHI tokens created per block.
    uint256 public sushiPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    mapping (uint256 => uint256) public suppliedTokens;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    mapping (IERC20 => uint256) public totalPoints;

    event Deposit(
        address indexed user,
        uint256 indexed poolId,
        uint256 depositAmount
    );

    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 withdrawAmount
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
    function addNewPool(
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        uint256 _rewardPoints,
        uint256 _startBlock
    )
        external
        onlyOwner
    {
        uint256 startingBlock = block.number > _startBlock
            ? block.number
            : _startBlock;

        totalPoints[_rewardToken] =
        totalPoints[_rewardToken] + _rewardPoints;

        poolInfo.push(
            PoolInfo(
                {
                    stakeToken: _stakeToken,
                    rewardToken: _rewardToken,
                    rewardPoints: _rewardPoints,
                    lastRewardBlock: startingBlock,
                    accSushiPerShare: 0
                }
            )
        );
    }

    function setPoolRewards(
        uint256 _poolId,
        uint256 _rewardPoints
    )
        external
        onlyOwner
    {
        PoolInfo memory pool = poolInfo[_poolId];
        IERC20 rewardToken = pool.rewardToken;

        totalPoints[rewardToken] = totalPoints[rewardToken]
            - pool.rewardPoints
            + _rewardPoints;

        poolInfo[_poolId].rewardPoints = _rewardPoints;
    }

    function pendingUserRewards(
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

        uint256 lpSupply = IERC20(pool.stakeToken).balanceOf(
            address(this)
        );

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {


            uint256 sushiReward = sushiPerBlock
                * pool.rewardPoints
                / totalPoints[pool.rewardToken];

            accSushiPerShare = accSushiPerShare + (sushiReward * 1e12 / lpSupply);
        }

        return user.depositAmount
            * accSushiPerShare
            / 1e12
            - user.rewardIssued;
    }

    function depositTokens(
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

        if (user.depositAmount > 0) {

            uint256 pending = user.depositAmount
                * pool.accSushiPerShare
                / 1e12
                - user.rewardIssued;

            sushi.transfer(
                msg.sender,
                pending
            );
        }

        safeTransferFrom(
            pool.stakeToken,
            address(msg.sender),
            address(this),
            _amount
        );

        user.depositAmount =
        user.depositAmount + _amount;

        user.rewardIssued = user.depositAmount
            * pool.accSushiPerShare
            / 1e12;

        emit Deposit(
            msg.sender,
            _poolId,
            _amount
        );
    }

    function massUpdatePools()
        external
    {
        uint256 length = poolInfo.length;
        for (uint256 poolId = 0; poolId < length; ++poolId) {
            updatePool(poolId);
        }
    }

    function updatePool(
        uint256 _poolId
    )
        public
    {
        PoolInfo storage pool = poolInfo[_poolId];

        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = IERC20(pool.stakeToken).balanceOf(
            address(this)
        );

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 totalReward = sushiPerBlock
            * pool.rewardPoints
            / totalPoints[pool.rewardToken];

        sushi.transfer(
            address(this),
            totalReward
        );

        pool.accSushiPerShare += totalReward
            * 1e12
            / lpSupply;

        pool.lastRewardBlock = block.number;
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

        user.depositAmount =
        user.depositAmount - _amount;

        uint256 pending = user.depositAmount
            * pool.accSushiPerShare
            / 1e12
            - user.rewardIssued;

        sushi.transfer(
            msg.sender,
            pending
        );

        user.rewardIssued = user.depositAmount
            * pool.accSushiPerShare
            / 1e12;

        safeTransfer(
            pool.stakeToken,
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
