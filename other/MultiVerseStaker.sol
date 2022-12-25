// SPDX-License-Identifier: -- vitally.eth --

pragma solidity =0.8.17;

interface IERC20 {

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

contract PoolAccounting is SafeERC20 {

    uint256 public poolCount;

    struct PoolInfo {
        uint256 rewardRate;
        uint256 periodFinish;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        IERC20 stakeToken;
        IERC20 rewardToken;
    }

    mapping(uint256 => PoolInfo) public poolInfo;
    mapping(IERC20 => mapping(IERC20 => uint256)) public poolId;

    mapping(uint256 => uint256) private _totalStaked;
    mapping(uint256 => mapping(address => uint256)) private _balances;

    function totalStaked(
        uint256 _poolId
    )
        public
        view
        returns (uint256)
    {
        return _totalStaked[_poolId];
    }

    function userBalance(
        uint256 _poolId,
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        return _balances[_poolId][_walletAddress];
    }

    function _stake(
        uint256 _poolId,
        uint256 _amount,
        address _address
    )
        internal
    {
        _totalStaked[_poolId] =
        _totalStaked[_poolId] + _amount;

        _balances[_poolId][_address] =
        _balances[_poolId][_address] + _amount;

        PoolInfo memory pool = poolInfo[_poolId];

        safeTransferFrom(
            pool.stakeToken,
            _address,
            address(this),
            _amount
        );
    }

    function _withdraw(
        uint256 _poolId,
        uint256 _amount,
        address _address
    )
        internal
    {
        _totalStaked[_poolId] =
        _totalStaked[_poolId] - _amount;

        _balances[_poolId][_address] =
        _balances[_poolId][_address] - _amount;

        PoolInfo memory pool = poolInfo[_poolId];

        safeTransfer(
            pool.stakeToken,
            _address,
            _amount
        );
    }
}

contract MultiVerseStaker is PoolAccounting {

    uint256 constant PRECISION = 1E18;
    address public ownerAddress;

    mapping(uint256 => mapping(address => uint256)) public userRewards;
    mapping(uint256 => mapping(address => uint256)) public userRewardPerTokenPaid;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress,
            "VerseStaker: INVALID_OWNER"
        );
        _;
    }

    modifier updatePool(
        uint256 _poolId
    ) {
        PoolInfo storage pool = poolInfo[_poolId];

        pool.rewardPerTokenStored = rewardPerToken(
            _poolId
        );

        pool.lastUpdateTime = lastTimeRewardApplicable(
            _poolId
        );
        _;
    }

    modifier updateUser(
        uint256 _poolId
    ) {
        PoolInfo memory pool = poolInfo[_poolId];

        userRewards[_poolId][msg.sender] = earned(
            _poolId,
            msg.sender
        );

        userRewardPerTokenPaid[_poolId][msg.sender] = pool.rewardPerTokenStored;
        _;
    }

    event PoolCreated(
        IERC20 indexed stakeToken,
        IERC20 indexed rewardToken
    );

    event RewardAdded(
        uint256 indexed poolId,
        uint256 reward
    );

    event TokenStaked(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event TokenWithdrawn(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event RewardPaid(
        address indexed user,
        uint256 indexed poolId,
        uint256 reward
    );

    constructor() {
        ownerAddress = msg.sender;
    }

    function createPool(
        IERC20 _stakeToken,
        IERC20 _rewardToken
    )
        external
        onlyOwner
    {
        require(
            poolId[_stakeToken][_rewardToken] == 0,
            "MultiVerseStaker: POOL_ALREADY_EXISTS"
        );

        poolCount = poolCount + 1;
        poolId[_stakeToken][_rewardToken] = poolCount;

        poolInfo[poolCount].stakeToken = _stakeToken;
        poolInfo[poolCount].rewardToken = _rewardToken;

        emit PoolCreated(
            _stakeToken,
            _rewardToken
        );
    }

    function lastTimeRewardApplicable(
        uint256 _poolId
    )
        public
        view
        returns (uint256)
    {
        PoolInfo memory pool = poolInfo[_poolId];

        return block.timestamp < pool.periodFinish
            ? block.timestamp
            : pool.periodFinish;
    }

    function rewardPerToken(
        uint256 _poolId
    )
        public
        view
        returns (uint256)
    {
        PoolInfo memory pool = poolInfo[_poolId];

        if (totalStaked(_poolId) == 0) {
            return pool.rewardPerTokenStored;
        }

        uint256 timeFrame = lastTimeRewardApplicable(_poolId)
            - pool.lastUpdateTime;

        uint256 extraFund = timeFrame
            * pool.rewardRate
            * PRECISION
            / totalStaked(_poolId);

        return pool.rewardPerTokenStored
            + extraFund;
    }

    function earned(
        uint256 _poolId,
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        uint256 difference = rewardPerToken(_poolId)
            - userRewardPerTokenPaid[_poolId][_walletAddress];

        return userBalance(_poolId, _walletAddress)
            * difference
            / PRECISION
            + userRewards[_poolId][_walletAddress];
    }

    function poolDeposit(
        uint256 _poolId,
        uint256 _stakeAmount
    )
        external
        updatePool(_poolId)
        updateUser(_poolId)
    {
        require(
            _stakeAmount > 0,
            "MultiVerseStaker: INVALID_AMOUNT"
        );

        address senderAddress = msg.sender;

        _stake(
            _poolId,
            _stakeAmount,
            senderAddress
        );

        emit TokenStaked(
            senderAddress,
            _poolId,
            _stakeAmount
        );
    }

    function poolWithdraw(
        uint256 _poolId,
        uint256 _withdrawAmount
    )
        public
        updatePool(_poolId)
        updateUser(_poolId)
    {
        require(
            _withdrawAmount > 0,
            "VerseStaker: INVALID_AMOUNT"
        );

        address senderAddress = msg.sender;

        _withdraw(
            _poolId,
            _withdrawAmount,
            senderAddress
        );

        emit TokenWithdrawn(
            senderAddress,
            _poolId,
            _withdrawAmount
        );
    }

    function exitPool(
        uint256 _poolId
    )
        external
    {
        uint256 withdrawAmount = userBalance(
            _poolId,
            msg.sender
        );

        poolWithdraw(
            _poolId,
            withdrawAmount
        );

        getReward(
            _poolId
        );
    }

    function getReward(
        uint256 _poolId
    )
        public
        updatePool(_poolId)
        updateUser(_poolId)
        returns (uint256 rewardAmount)
    {
        address senderAddress = msg.sender;

        rewardAmount = earned(
            _poolId,
            senderAddress
        );

        if (rewardAmount == 0) {
            return 0;
        }

        userRewards[_poolId][senderAddress] = 0;
        PoolInfo memory pool = poolInfo[_poolId];

        safeTransfer(
            pool.rewardToken,
            senderAddress,
            rewardAmount
        );

        emit RewardPaid(
            senderAddress,
            _poolId,
            rewardAmount
        );
    }

    function changeOwner(
        address _newOwner
    )
        external
        onlyOwner
    {
        ownerAddress = _newOwner;
    }

    function notifyDistribution(
        uint256 _poolId,
        uint256 _rewardAmount,
        uint256 _rewardTimeFrame
    )
        external
        onlyOwner
        updatePool(_poolId)
    {
        require(
            _rewardTimeFrame > 0,
            "VerseStaker: INVALID_TIME_FRAME"
        );

        PoolInfo storage pool = poolInfo[_poolId];

        if (block.timestamp >= pool.periodFinish) {
            pool.rewardRate = _rewardAmount
                / _rewardTimeFrame;
        }
            else
        {
            uint256 remaining = pool.periodFinish
                - block.timestamp;

            uint256 leftOver = remaining
                * pool.rewardRate;

            uint256 newTotal = _rewardAmount
                + leftOver;

            pool.rewardRate = newTotal
                / _rewardTimeFrame;
        }

        pool.lastUpdateTime = block.timestamp;
        pool.periodFinish = pool.lastUpdateTime
            + _rewardTimeFrame;

        safeTransferFrom(
            pool.rewardToken,
            msg.sender,
            address(this),
            _rewardAmount
        );

        emit RewardAdded(
            _poolId,
            _rewardAmount
        );
    }
}
