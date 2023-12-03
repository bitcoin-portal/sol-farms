// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.23;

import "./TokenWrapper.sol";

contract PrivateFarm2X is TokenWrapper {

    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardTokenA;
    IERC20 public immutable rewardTokenB;

    uint256 public rewardRateA;
    uint256 public rewardRateB;

    uint256 public periodFinished;
    uint256 public rewardDuration;
    uint256 public lastUpdateTime;

    uint256 public perTokenStoredA;
    uint256 public perTokenStoredB;

    uint256 constant PRECISION = 1E18;

    mapping(address => uint256) public userRewardsA;
    mapping(address => uint256) public userRewardsB;

    mapping(address => uint256) public perTokenPaidA;
    mapping(address => uint256) public perTokenPaidB;

    address public ownerAddress;
    address public proposedOwner;
    address public managerAddress;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress,
            "PrivateFarm2X: INVALID_OWNER"
        );
        _;
    }

    modifier onlyManager() {
        require(
            msg.sender == managerAddress,
            "PrivateFarm2X: INVALID_MANAGER"
        );
        _;
    }

    modifier updateFarm() {
        perTokenStoredA = rewardPerTokenA();
        perTokenStoredB = rewardPerTokenB();

        lastUpdateTime = lastTimeRewardApplicable();
        _;
    }

    modifier updateUser() {

        userRewardsA[msg.sender] = earnedA(
            msg.sender
        );

        userRewardsB[msg.sender] = earnedB(
            msg.sender
        );

        perTokenPaidA[msg.sender] = perTokenStoredA;
        perTokenPaidB[msg.sender] = perTokenStoredB;
        _;
    }

    modifier updateSender(
        address _sender
    ) {
        userRewardsA[_sender] = earnedA(
            _sender
        );

        userRewardsB[_sender] = earnedB(
            _sender
        );

        perTokenPaidA[_sender] = perTokenStoredA;
        perTokenPaidB[_sender] = perTokenStoredB;
        _;
    }

    event Staked(
        address indexed user,
        uint256 tokenAmount
    );

    event Withdrawn(
        address indexed user,
        uint256 tokenAmount
    );

    event RewardAdded(
        uint256 rewardRateA,
        uint256 rewardRateB,
        uint256 tokenAmountA,
        uint256 tokenAmountB
    );

    event RewardPaid(
        address indexed user,
        uint256 tokenAmountA,
        uint256 tokenAmountB
    );

    event Recovered(
        IERC20 indexed token,
        uint256 tokenAmount
    );

    event RewardsDurationUpdated(
        uint256 newRewardDuration
    );

    event OwnerProposed(
        address proposedOwner
    );

    event OwnerChanged(
        address newOwner
    );

    event ManagerChanged(
        address newManager
    );

    constructor(
        IERC20 _stakeToken,
        IERC20 _rewardTokenA,
        IERC20 _rewardTokenB,
        uint256 _defaultDuration
    ) {
        require(
            _defaultDuration > 0,
            "PrivateFarm2X: INVALID_DURATION"
        );

        stakeToken = _stakeToken;
        rewardTokenA = _rewardTokenA;
        rewardTokenB = _rewardTokenB;

        ownerAddress = msg.sender;
        managerAddress = msg.sender;

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
     * @dev Relative value on reward for
     * single staked token for token A
     */
    function rewardPerTokenA()
        public
        view
        returns (uint256)
    {
        if (_totalStaked == 0) {
            return perTokenStoredA;
        }

        uint256 timeFrame = lastTimeRewardApplicable()
            - lastUpdateTime;

        uint256 extraFund = timeFrame
            * rewardRateA
            * PRECISION
            / _totalStaked;

        return perTokenStoredA
            + extraFund;
    }

    /**
     * @dev Relative value on reward for
     * single staked token for token B
     */
    function rewardPerTokenB()
        public
        view
        returns (uint256)
    {
        if (_totalStakedSQRT == 0) {
            return perTokenStoredB;
        }

        uint256 timeFrame = lastTimeRewardApplicable()
            - lastUpdateTime;

        uint256 extraFund = timeFrame
            * rewardRateB
            * PRECISION
            / _totalStakedSQRT;

        return perTokenStoredB
            + extraFund;
    }

    /**
     * @dev Reports earned amount of token A
     * by wallet address not yet collected
     */
    function earnedA(
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        uint256 difference = rewardPerTokenA()
            - perTokenPaidA[_walletAddress];

        return _balances[_walletAddress]
            * difference
            / PRECISION
            + userRewardsA[_walletAddress];
    }

    /**
     * @dev Reports earned amount of token B
     * by wallet address not yet collected
     */
    function earnedB(
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        uint256 difference = rewardPerTokenB()
            - perTokenPaidB[_walletAddress];

        return Babylonian.sqrt(
                _balances[_walletAddress]
            )
            * difference
            / PRECISION
            + userRewardsB[_walletAddress];
    }

    function makeDepositForUser(
        address _stakeOwner,
        uint256 _stakeAmount
    )
        external
        onlyOwner
    {
        _farmDeposit(
            _stakeOwner,
            _stakeAmount
        );
    }

    function makeDepositForUserBulk(
        address[] calldata _stakeOwners,
        uint256[] calldata _stakeAmounts
    )
        external
        onlyManager
    {
        require(
            _stakeOwners.length == _stakeAmounts.length,
            "PrivateFarm2X: INVALID_INPUTS"
        );

        uint256 i;
        uint256 l = _stakeOwners.length;

        for (i; i < l;) {
            _farmDeposit(
                _stakeOwners[i],
                _stakeAmounts[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Performs deposit of staked token into the farm
     */
    function _farmDeposit(
        address _stakeOwner,
        uint256 _stakeAmount
    )
        private
        updateFarm()
        updateUser()
    {
        _stake(
            _stakeAmount,
            _stakeOwner
        );

        safeTransferFrom(
            stakeToken,
            msg.sender,
            address(this),
            _stakeAmount
        );

        emit Staked(
            _stakeOwner,
            _stakeAmount
        );
    }

    /**
     * @dev Allows to withdraw staked tokens and claim rewards
     */
    function exitFarm()
        external
    {
        _exitFarm(
            msg.sender
        );
    }

    /**
     * @dev Forced withdrawal of staked tokens and claim rewards
     * for the specified wallet address if leaving company or...
     */
    function exitFarmForced(
        address _withdrawAddress
    )
        external
        onlyOwner
    {
        _exitFarm(
            _withdrawAddress
        );
    }

    function claimReward()
        external
    {
        _claimReward(
            msg.sender
        );
    }

    function farmWithdraw(
        uint256 _withdrawAmount
    )
        external
    {
        _farmWithdraw(
            msg.sender,
            _withdrawAmount
        );
    }

    /**
     * @dev Allows to withdraw staked tokens and claim rewards
     */
    function _exitFarm(
        address _exitAddress
    )
        private
    {
        _claimReward(
            _exitAddress
        );

        _farmWithdraw(
            _exitAddress,
            _balances[_exitAddress]
        );
    }

    /**
     * @dev Allows to claim accumulated rewards up to date
     */
    function _claimReward(
        address _claimAddress
    )
        private
        updateFarm()
        updateUser()
        returns (
            uint256 rewardAmountA,
            uint256 rewardAmountB
        )
    {
        rewardAmountA = earnedA(
            _claimAddress
        );

        rewardAmountB = earnedB(
            _claimAddress
        );

        require(
            rewardAmountA > 0 || rewardAmountB > 0,
            "PrivateFarm2X: NOTHING_TO_CLAIM"
        );

        delete userRewardsA[
            _claimAddress
        ];

        delete userRewardsB[
            _claimAddress
        ];

        if (rewardAmountA > 0) {
            safeTransfer(
                rewardTokenA,
                _claimAddress,
                rewardAmountA
            );
        }

        if (rewardAmountB > 0) {
            safeTransfer(
                rewardTokenB,
                _claimAddress,
                rewardAmountB
            );
        }

        emit RewardPaid(
            _claimAddress,
            rewardAmountA,
            rewardAmountB
        );
    }

    /**
     * @dev Performs withdrawal of staked token from the farm
     */
    function _farmWithdraw(
        address _withdrawAddress,
        uint256 _withdrawAmount
    )
        private
        updateFarm()
        updateUser()
    {
        if (block.timestamp < periodFinished) {
            require(
                _totalStaked > _withdrawAmount,
                "PrivateFarm2X: STILL_EARNING"
            );
        }

        _withdraw(
            _withdrawAmount,
            _withdrawAddress
        );

        safeTransfer(
            stakeToken,
            _withdrawAddress,
            _withdrawAmount
        );

        emit Withdrawn(
            _withdrawAddress,
            _withdrawAmount
        );
    }

    /**
     * @dev Allows to invoke owner-change procedure
     */
    function proposeNewOwner(
        address _newOwner
    )
        external
        onlyOwner
    {
        if (_newOwner == ZERO_ADDRESS) {
            revert("PrivateFarm2X: WRONG_ADDRESS");
        }

        proposedOwner = _newOwner;

        emit OwnerProposed(
            _newOwner
        );
    }

    /**
     * @dev Finalizes owner-change 2-step procedure
     */
    function claimOwnership()
        external
    {
        require(
            msg.sender == proposedOwner,
            "PrivateFarm2X: INVALID_CANDIDATE"
        );

        ownerAddress = proposedOwner;

        emit OwnerChanged(
            ownerAddress
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
            revert("PrivateFarm2X: WRONG_ADDRESS");
        }

        managerAddress = _newManager;

        emit ManagerChanged(
            _newManager
        );
    }

    /**
     * @dev Allows to recover ANY tokens
     * from the private farm contract
     */
    function recoverTokens(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
        onlyOwner
    {
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
            "PrivateFarm2X: INVALID_DURATION"
        );

        require(
            block.timestamp > periodFinished,
            "PrivateFarm2X: ONGOING_DISTRIBUTION"
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
    function setRewardRates(
        uint256 _newRewardRateA,
        uint256 _newRewardRateB
    )
        external
        onlyManager
        updateFarm()
    {
        require(
            _totalStaked > 0,
            "PrivateFarm2X: NO_STAKERS"
        );

        require(
            _newRewardRateA > 0,
            "PrivateFarm2X: INVALID_RATE_A"
        );

        require(
            _newRewardRateB > 0,
            "PrivateFarm2X: INVALID_RATE_B"
        );

        uint256 currentPeriodFinish = periodFinished;

        lastUpdateTime = block.timestamp;
        periodFinished = block.timestamp
            + rewardDuration;

        if (block.timestamp < currentPeriodFinish) {

            require(
                _newRewardRateA >= rewardRateA,
                "PrivateFarm2X: RATE_A_CANT_DECREASE"
            );

            require(
                _newRewardRateB >= rewardRateB,
                "PrivateFarm2X: RATE_B_CANT_DECREASE"
            );

            uint256 remainingTime = currentPeriodFinish
                - block.timestamp;

            uint256 rewardRemainsA = remainingTime
                * rewardRateA;

            uint256 rewardRemainsB = remainingTime
                * rewardRateB;

            safeTransfer(
                rewardTokenA,
                managerAddress,
                rewardRemainsA
            );

            safeTransfer(
                rewardTokenB,
                managerAddress,
                rewardRemainsB
            );
        }

        rewardRateA = _newRewardRateA;
        rewardRateB = _newRewardRateB;

        uint256 newRewardAmountA = rewardDuration
            * _newRewardRateA;

        uint256 newRewardAmountB = rewardDuration
            * _newRewardRateB;

        safeTransferFrom(
            rewardTokenA,
            managerAddress,
            address(this),
            newRewardAmountA
        );

        safeTransferFrom(
            rewardTokenB,
            managerAddress,
            address(this),
            newRewardAmountB
        );

        emit RewardAdded(
            _newRewardRateA,
            _newRewardRateB,
            newRewardAmountA,
            newRewardAmountB
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
        updateSender(_recipient)
        returns (bool)
    {
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
        updateSender(_sender)
        updateSender(_recipient)
        returns (bool)
    {
        if (_allowances[_sender][msg.sender] != type(uint256).max) {
            _allowances[_sender][msg.sender] -= _amount;
        }

        _transfer(
            _sender,
            _recipient,
            _amount
        );

        return true;
    }
}
