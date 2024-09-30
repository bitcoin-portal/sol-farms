// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./TokenWrapper.sol";

error LockedUntil(
    uint256 unlockTime
);

contract TimeLockFarm is TokenWrapper {

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardRate;
    uint256 public periodFinished;
    uint256 public rewardDuration;
    uint256 public lastUpdateTime;
    uint256 public perTokenStored;

    uint256 public immutable timeLock;
    uint256 constant PRECISION = 1E18;

    mapping(address => uint256) public unlockTime;
    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public perTokenPaid;

    address public managerAddress;
    address public immutable ownerAddress;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress,
            "TimeLockFarm: INVALID_OWNER"
        );
        _;
    }

    modifier onlyManager() {
        require(
            msg.sender == managerAddress,
            "TimeLockFarm: INVALID_MANAGER"
        );
        _;
    }

    modifier updateFarm() {
        perTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        _;
    }

    modifier updateUser() {
        userRewards[msg.sender] = earned(msg.sender);
        perTokenPaid[msg.sender] = perTokenStored;
        _;
    }

    modifier updateAddy(address sender) {
        userRewards[sender] = earned(sender);
        perTokenPaid[sender] = perTokenStored;
        _;
    }

    event RewardAdded(
        uint256 rewardRate,
        uint256 tokenAmount
    );

    event RewardPaid(
        address indexed user,
        uint256 tokenAmount
    );

    constructor(
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        address _ownerAddress,
        address _managerAddress,
        uint256 _defaultDuration,
        uint256 _defaultTimeLock
    ) {
        require(
            _defaultDuration > 0,
            "TimeLockFarm: INVALID_DURATION"
        );

        stakeToken = _stakeToken;
        rewardToken = _rewardToken;

        ownerAddress = _ownerAddress;
        managerAddress = _managerAddress;

        timeLock = _defaultTimeLock;
        rewardDuration = _defaultDuration;
    }

    /**
     * @dev Tracks timestamp for when reward was applied last time
     */
    function lastTimeRewardApplicable()
        public
        view
        returns (uint256 res)
    {
        res = block.timestamp < periodFinished
            ? block.timestamp
            : periodFinished;
    }

    /**
     * @dev Relative value on reward for single staked token
     */
    function rewardPerToken()
        public
        view
        returns (uint256)
    {
        if (_totalStaked == 0) {
            return perTokenStored;
        }

        uint256 timeFrame = lastTimeRewardApplicable()
            - lastUpdateTime;

        uint256 extraFund = timeFrame
            * rewardRate
            * PRECISION
            / _totalStaked;

        return perTokenStored
            + extraFund;
    }

    /**
     * @dev Reports earned amount by wallet address not yet collected
     */
    function earned(
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        uint256 difference = rewardPerToken()
            - perTokenPaid[_walletAddress];

        return _balances[_walletAddress]
            * difference
            / PRECISION
            + userRewards[_walletAddress];
    }

    /**
     * @dev Performs deposit of staked token into the farm
     */
    function farmDeposit(
        uint256 _stakeAmount
    )
        external
        updateFarm()
        updateUser()
    {
        address senderAddress = msg.sender;

        _stake(
            _stakeAmount,
            senderAddress
        );

        unlockTime[senderAddress] = block.timestamp
            + timeLock;

        safeTransferFrom(
            stakeToken,
            senderAddress,
            address(this),
            _stakeAmount
        );

        emit Staked(
            senderAddress,
            _stakeAmount
        );
    }

    /**
     * @dev Performs withdrawal of staked token from the farm
     */
    function farmWithdraw(
        uint256 _withdrawAmount
    )
        public
        updateFarm()
        updateUser()
    {
        if (block.timestamp < periodFinished) {
            require(
                _totalStaked > _withdrawAmount,
                "TimeLockFarm: STILL_EARNING"
            );
        }

        address senderAddress = msg.sender;

        if (tokensLocked(senderAddress) == true) {
            revert LockedUntil(
                unlockTime[senderAddress]
            );
        }

        _withdraw(
            _withdrawAmount,
            senderAddress
        );

        safeTransfer(
            stakeToken,
            senderAddress,
            _withdrawAmount
        );

        emit Withdrawn(
            senderAddress,
            _withdrawAmount
        );
    }

    /**
     * @dev Returns a flag if users tokens are still locked
     */
    function tokensLocked(
        address _walletAddress
    )
        public
        view
        returns (bool)
    {
        return block.timestamp < unlockTime[_walletAddress];
    }

    /**
     * @dev Allows to withdraw staked tokens and claim rewards
     */
    function exitFarm()
        external
    {
        farmWithdraw(
            _balances[
                msg.sender
            ]
        );

        claimReward();
    }

    /**
     * @dev Allows to claim accumulated rewards up to date
     */
    function claimReward()
        public
        updateFarm()
        updateUser()
        returns (uint256 rewardAmount)
    {
        address senderAddress = msg.sender;

        rewardAmount = earned(
            senderAddress
        );

        require(
            rewardAmount > 0,
            "TimeLockFarm: NOTHING_TO_CLAIM"
        );

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

    /**
     * @dev Allows to change manager of the farm
     */
    function changeManager(
        address _newManager
    )
        external
        onlyOwner
    {
        if (_newManager == ZERO_ADDRESS) {
            revert("TimeLockFarm: WRONG_ADDRESS");
        }

        managerAddress = _newManager;

        emit ManagerChanged(
            _newManager
        );
    }

    /**
     * @dev Allows to recover accidentally sent tokens
     * into the farm except stake and reward tokens
     */
    function recoverToken(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
    {
        if (tokenAddress == stakeToken) {
            revert("TimeLockFarm: INVALID_TOKEN");
        }

        if (tokenAddress == rewardToken) {
            revert("TimeLockFarm: INVALID_TOKEN");
        }

        safeTransfer(
            tokenAddress,
            ownerAddress,
            tokenAmount
        );

        emit Recovered(
            tokenAddress,
            tokenAmount
        );
    }

    /**
     * @dev Manager sets the cycle duration for distribution
     * in seconds and can't be changed during active cycle
     */
    function setRewardDuration(
        uint256 _rewardDuration
    )
        external
        onlyManager
    {
        require(
            _rewardDuration > 0,
            "TimeLockFarm: INVALID_DURATION"
        );

        require(
            block.timestamp > periodFinished,
            "TimeLockFarm: ONGOING_DISTRIBUTION"
        );

        rewardDuration = _rewardDuration;

        emit RewardsDurationUpdated(
            _rewardDuration
        );
    }

    /**
     * @dev Manager sets reward per second to be distributed
     * and invokes initial distribution to be started right away,
     * must have some tokens already staked before executing.
     */
    function setRewardRate(
        uint256 _newRewardRate
    )
        external
        onlyManager
        updateFarm()
    {
        require(
            _totalStaked > 0,
            "TimeLockFarm: NO_STAKERS"
        );

        require(
            _newRewardRate > 0,
            "TimeLockFarm: INVALID_RATE"
        );

        uint256 currentPeriodFinish = periodFinished;

        lastUpdateTime = block.timestamp;
        periodFinished = block.timestamp
            + rewardDuration;

        if (block.timestamp < currentPeriodFinish) {

            require(
                _newRewardRate >= rewardRate,
                "TimeLockFarm: RATE_CANT_DECREASE"
            );

            uint256 remainingTime = currentPeriodFinish
                - block.timestamp;

            uint256 rewardRemains = remainingTime
                * rewardRate;

            safeTransfer(
                rewardToken,
                managerAddress,
                rewardRemains
            );
        }

        rewardRate = _newRewardRate;

        uint256 newRewardAmount = rewardDuration
            * _newRewardRate;

        safeTransferFrom(
            rewardToken,
            managerAddress,
            address(this),
            newRewardAmount
        );

        emit RewardAdded(
            _newRewardRate,
            newRewardAmount
        );
    }

    /**
     * @dev Allows to transfer receipt tokens
     */
    function transfer(
        address _recipient,
        uint256 _amount
    )
        external
        updateFarm()
        updateUser()
        updateAddy(_recipient)
        returns (bool)
    {
        if (tokensLocked(msg.sender) == true) {
            revert LockedUntil(
                unlockTime[msg.sender]
            );
        }

        _transfer(
            msg.sender,
            _recipient,
            _amount
        );

        return true;
    }

    /**
     * @dev Allows to transfer receipt tokens on owner's behalf
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        external
        updateFarm()
        updateAddy(_sender)
        updateAddy(_recipient)
        returns (bool)
    {
        if (_allowances[_sender][msg.sender] != type(uint256).max) {
            _allowances[_sender][msg.sender] -= _amount;
        }

        if (tokensLocked(_sender) == true) {
            revert LockedUntil(
                unlockTime[_sender]
            );
        }

        _transfer(
            _sender,
            _recipient,
            _amount
        );

        return true;
    }
}
