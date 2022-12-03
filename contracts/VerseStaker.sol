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

contract WrappedToken is SafeERC20 {

    IERC20 public immutable stakeToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(
        IERC20 _stakeToken
    ) {
        stakeToken = _stakeToken;
    }

    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _totalSupply;
    }

    function balanceOf(
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
        _totalSupply =
        _totalSupply + _amount;

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
        _totalSupply =
        _totalSupply - _amount;

        _balances[_address] =
        _balances[_address] - _amount;

        safeTransfer(
            stakeToken,
            _address,
            _amount
        );
    }
}

contract VerseStaker is WrappedToken {

    IERC20 public immutable rewardToken;

    uint256 public constant PRECISION = 1E18;
    uint256 public constant DURATION_MIN = 5 weeks;
    address public constant ZERO_ADDRESS = address(0);

    uint256 public rewardRate;
    uint256 public periodFinish;
    address public ownerAddress;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress,
            "VerseStaker: INVALID_OWNER"
        );
        _;
    }

    modifier updateReward(
        address _account
    ) {

        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (_account != ZERO_ADDRESS) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
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
        WrappedToken(
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
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }

        uint256 timeFrame = lastTimeRewardApplicable()
            - lastUpdateTime;

        uint256 extraFund = timeFrame
            * rewardRate
            * PRECISION
            / totalSupply();

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

        return balanceOf(_walletAddress)
            * difference
            / PRECISION
            + rewards[_walletAddress];
    }

    function stake(
        uint256 _stakeAmount
    )
        external
        updateReward(msg.sender)
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

    function withdraw(
        uint256 _withdrawAmount
    )
        public
        updateReward(msg.sender)
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

    function exit()
        external
    {
        uint256 withdrawAmount = balanceOf(
            msg.sender
        );

        withdraw(
            withdrawAmount
        );

        getReward();
    }

    function getReward()
        public
        updateReward(msg.sender)
        returns (uint256 rewardAmount)
    {
        address senderAddress = msg.sender;

        rewardAmount = earned(
            senderAddress
        );

        if (rewardAmount == 0) return 0;

        rewards[senderAddress] = 0;

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

    function notifyRewardAmount(
        uint256 _rewardAmount
    )
        external
        onlyOwner
        updateReward(ZERO_ADDRESS)
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = _rewardAmount
                / DURATION_MIN;
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
                / DURATION_MIN;
        }

        lastUpdateTime = block.timestamp;

        periodFinish = lastUpdateTime
            + DURATION_MIN;

        emit RewardAdded(
            _rewardAmount
        );
    }
}
