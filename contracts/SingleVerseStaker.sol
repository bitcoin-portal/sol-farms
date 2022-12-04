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

contract TokenWrapper is SafeERC20 {

    IERC20 public immutable stakeToken;

    uint256 private _totalStaked;
    mapping(address => uint256) private _balances;

    constructor(
        IERC20 _stakeToken
    ) {
        stakeToken = _stakeToken;
    }

    function totalStaked()
        public
        view
        returns (uint256)
    {
        return _totalStaked;
    }

    function userBalance(
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        return _balances[_walletAddress];
    }

    function _stake(
        uint256 _amount,
        address _address
    )
        internal
    {
        _totalStaked =
        _totalStaked + _amount;

        _balances[_address] =
        _balances[_address] + _amount;

        safeTransferFrom(
            stakeToken,
            _address,
            address(this),
            _amount
        );
    }

    function _withdraw(
        uint256 _amount,
        address _address
    )
        internal
    {
        _totalStaked =
        _totalStaked - _amount;

        _balances[_address] =
        _balances[_address] - _amount;

        safeTransfer(
            stakeToken,
            _address,
            _amount
        );
    }
}

contract SingleVerseStaker is TokenWrapper {

    IERC20 public immutable rewardToken;

    uint256 public constant PRECISION = 1E18;

    uint256 public rewardRate;
    uint256 public rewardTotal;
    uint256 public periodFinish;
    address public ownerAddress;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress,
            "VerseStaker: INVALID_OWNER"
        );
        _;
    }

    modifier updatePool() {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        _;
    }

    modifier updateUser() {
        userRewards[msg.sender] = earned(msg.sender);
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;
        _;
    }

    event RewardAdded(
        uint256 reward
    );

    event Staked(
        address indexed user,
        uint256 amount
    );

    event Withdrawn(
        address indexed user,
        uint256 amount
    );

    event RewardPaid(
        address indexed user,
        uint256 reward
    );

    constructor(
        IERC20 _stakeToken,
        IERC20 _rewardToken
    )
        TokenWrapper(
            _stakeToken
        )
    {
        rewardToken = _rewardToken;
        ownerAddress = msg.sender;
    }

    function lastTimeRewardApplicable()
        public
        view
        returns (uint256)
    {
        return block.timestamp < periodFinish
            ? block.timestamp
            : periodFinish;
    }

    function rewardPerToken()
        public
        view
        returns (uint256)
    {
        if (totalStaked() == 0) {
            return rewardPerTokenStored;
        }

        uint256 timeFrame = lastTimeRewardApplicable()
            - lastUpdateTime;

        uint256 extraFund = timeFrame
            * rewardRate
            * PRECISION
            / totalStaked();

        return rewardPerTokenStored
            + extraFund;
    }

    function earned(
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        uint256 difference = rewardPerToken()
            - userRewardPerTokenPaid[_walletAddress];

        return userBalance(_walletAddress)
            * difference
            / PRECISION
            + userRewards[_walletAddress];
    }

    function poolDeposit(
        uint256 _stakeAmount
    )
        external
        updatePool()
        updateUser()
    {
        require(
            _stakeAmount > 0,
            "VerseStaker: INVALID_AMOUNT"
        );

        address senderAddress = msg.sender;

        _stake(
            _stakeAmount,
            senderAddress
        );

        emit Staked(
            senderAddress,
            _stakeAmount
        );
    }

    function poolWithdraw(
        uint256 _withdrawAmount
    )
        public
        updatePool()
        updateUser()
    {
        require(
            _withdrawAmount > 0,
            "VerseStaker: INVALID_AMOUNT"
        );

        address senderAddress = msg.sender;

        _withdraw(
            _withdrawAmount,
            senderAddress
        );

        emit Withdrawn(
            senderAddress,
            _withdrawAmount
        );
    }

    function exitPool()
        external
    {
        uint256 withdrawAmount = userBalance(
            msg.sender
        );

        poolWithdraw(
            withdrawAmount
        );

        getReward();
    }

    function getReward()
        public
        updatePool()
        updateUser()
        returns (uint256 rewardAmount)
    {
        address senderAddress = msg.sender;

        rewardAmount = earned(
            senderAddress
        );

        if (rewardAmount == 0) {
            return 0;
        }

        userRewards[senderAddress] = 0;

        safeTransfer(
            rewardToken,
            senderAddress,
            rewardAmount
        );

        emit RewardPaid(
            senderAddress,
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

    function updateRewards(
        uint256 _rewardAmount,
        uint256 _rewardTimeFrame
    )
        external
        onlyOwner
        updatePool()
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = _rewardAmount
                / _rewardTimeFrame;
        }
            else
        {
            uint256 remaining = periodFinish
                - block.timestamp;

            uint256 leftOver = remaining
                * rewardRate;

            uint256 newTotal = _rewardAmount
                + leftOver;

            rewardRate = newTotal
                / _rewardTimeFrame;
        }

        lastUpdateTime = block.timestamp;

        periodFinish = lastUpdateTime
            + _rewardTimeFrame;

        emit RewardAdded(
            _rewardAmount
        );
    }
}
