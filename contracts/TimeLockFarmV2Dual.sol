// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.23;

import "./TokenWrapper.sol";

contract TimeLockFarmV2Dual is TokenWrapper {

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

    struct Stake {
        uint256 amount;
        uint256 createTime;
        uint256 unlockTime;
    }

    mapping(address => Stake[]) public stakes;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress,
            "TimeLockFarmV2Dual: INVALID_OWNER"
        );
        _;
    }

    modifier onlyManager() {
        require(
            msg.sender == managerAddress,
            "TimeLockFarmV2Dual: INVALID_MANAGER"
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
        _updateUser(
            msg.sender
        );
        _;
    }

    modifier updateAddy(
        address _userAddress
    ) {
        _updateUser(
            _userAddress
        );
        _;
    }

    function _updateUser(
        address _userAddress
    )
        private
    {
        userRewardsA[_userAddress] = earnedA(
            _userAddress
        );

        userRewardsB[_userAddress] = earnedB(
            _userAddress
        );

        perTokenPaidA[_userAddress] = perTokenStoredA;
        perTokenPaidB[_userAddress] = perTokenStoredB;
    }

    event Staked(
        address indexed user,
        uint256 tokenAmount,
        uint256 lockingTime
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
            "TimeLockFarmV2Dual: INVALID_DURATION"
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
     * @dev Relative value on reward for single staked token
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
     * @dev Relative value on reward for single staked token
     */
    function rewardPerTokenB()
        public
        view
        returns (uint256)
    {
        if (_totalStaked == 0) {
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

        return unlockable(_walletAddress)
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
                unlockable(_walletAddress)
            )
            * difference
            / PRECISION
            + userRewardsB[_walletAddress];
    }

    /**
     * @dev Calculates amount of stakes for user wallet
     */
    function stakeCount(
        address _walletAddress
    )
        external
        view
        returns (uint256)
    {
        Stake[] memory walletStakes = stakes[
            _walletAddress
        ];

        return walletStakes.length;
    }

    /**
     * @dev Calculates unlockable amount for user wallet
     * based on user stakes and current timestamp
     */
    function unlockable(
        address _walletAddress
    )
        public
        view
        returns (uint256 totalAmount)
    {
        Stake[] memory walletStakes = stakes[
            _walletAddress
        ];

        uint256 i;
        uint256 length = walletStakes.length;

        while (i < length) {
            unchecked {
                totalAmount += _calculateUnlockableAmount(
                    walletStakes[i]
                );
                ++i;
            }
        }
    }

    /**
     * @dev Performs deposit of staked token into the farm
     */
    function makeDepositForUser(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime
    )
        external
        onlyManager
    {
        _farmDeposit(
            _stakeOwner,
            _stakeAmount,
            _lockingTime
        );
    }

    function _farmDeposit(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime
    )
        private
        updateFarm()
        updateAddy(_stakeOwner)
    {
        _stake(
            _stakeAmount,
            _stakeOwner
        );

        stakes[_stakeOwner].push(
            Stake(
                _stakeAmount,
                block.timestamp,
                block.timestamp + _lockingTime
            )
        );

        safeTransferFrom(
            stakeToken,
            msg.sender,
            address(this),
            _stakeAmount
        );

        emit Staked(
            _stakeOwner,
            _stakeAmount,
            _lockingTime
        );
    }

    /**
     * @dev Forced withdrawal of staked tokens and claim rewards
     * for the specified wallet address if leaving company or...
     */
    function destroyStaker(
        address _withdrawAddress
    )
        external
        onlyOwner
    {
        _destroyStaker(
            _withdrawAddress
        );
    }

    function _destroyStaker(
        address _withdrawAddress
    )
        private
        updateFarm()
        updateAddy(_withdrawAddress)
    {
        _claimReward(
            _withdrawAddress
        );

        _farmWithdraw(
            _withdrawAddress,
            unlockable(
                msg.sender
            )
        );

        delete stakes[
            _withdrawAddress
        ];
    }

    function destroyStakerBulk(
        address[] calldata _withdrawAddresses
    )
        external
        onlyOwner
    {
        uint256 i;
        uint256 l = _withdrawAddresses.length;

        while (i < l) {

            _destroyStaker(
                _withdrawAddresses[i]
            );

            unchecked {
                ++i;
            }
        }
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
        _farmWithdraw(
            msg.sender,
            _withdrawAmount
        );
    }

    /**
     * @dev Performs withdrawal of staked token from the farm
     */
    function _farmWithdraw(
        address _withdrawAddress,
        uint256 _withdrawAmount
    )
        internal
    {
        _unlock(
            _withdrawAmount,
            _withdrawAddress
        );

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
     * @dev Allows to withdraw unlocked tokens and claim rewards
     */
    function exitFarm()
        external
    {
        farmWithdraw(
            unlockable(
                msg.sender
            )
        );

        claimReward();
    }

    function claimReward()
        public
        updateFarm()
        updateUser()
    {
        _claimReward(
            msg.sender
        );
    }

    /**
     * @dev Allows to claim accumulated rewards
     */
    function _claimReward(
        address _claimAddress
    )
        private
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
            "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
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
     * @dev Allows to invoke owner-change procedure
     */
    function proposeNewOwner(
        address _newOwner
    )
        external
        onlyOwner
    {
        if (_newOwner == ZERO_ADDRESS) {
            revert("TimeLockFarmV2Dual: WRONG_ADDRESS");
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
            "TimeLockFarmV2Dual: INVALID_CANDIDATE"
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
            revert("TimeLockFarmV2Dual: WRONG_ADDRESS");
        }

        managerAddress = _newManager;

        emit ManagerChanged(
            _newManager
        );
    }

    /**
     * @dev Allows to recover ANY tokens
     * from the private farm contract.
     * God mode feature for admin multisig.
     */
    function recoverTokens(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
        onlyManager
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
            "TimeLockFarmV2Dual: INVALID_DURATION"
        );

        require(
            block.timestamp > periodFinished,
            "TimeLockFarmV2Dual: ONGOING_DISTRIBUTION"
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
            "TimeLockFarmV2Dual: NO_STAKERS"
        );

        require(
            _newRewardRateA > 0,
            "TimeLockFarmV2Dual: INVALID_RATE_A"
        );

        require(
            _newRewardRateB > 0,
            "TimeLockFarmV2Dual: INVALID_RATE_B"
        );

        uint256 currentPeriodFinish = periodFinished;

        lastUpdateTime = block.timestamp;
        periodFinished = block.timestamp
            + rewardDuration;

        if (block.timestamp < currentPeriodFinish) {

            require(
                _newRewardRateA >= rewardRateA,
                "TimeLockFarmV2Dual: RATE_A_CANT_DECREASE"
            );

            require(
                _newRewardRateB >= rewardRateB,
                "TimeLockFarmV2Dual: RATE_B_CANT_DECREASE"
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

    function _unlock(
        uint256 _withdrawAmount,
        address _senderAddress
    )
        private
    {
        Stake[] storage userStakes = stakes[
            _senderAddress
        ];

        uint256 i;
        uint256 unlockedAmount;

        while (i < userStakes.length) {

            Stake storage userStake = userStakes[i];

            uint256 unlockableAmount = _calculateUnlockableAmount(
                userStake
            );

            if (unlockableAmount > 0) {

                uint256 remainingAmount = _withdrawAmount
                    - unlockedAmount;

                uint256 unlockAmount = unlockableAmount < remainingAmount
                    ? unlockableAmount
                    : remainingAmount;

                unlockedAmount += unlockAmount;
                userStake.amount -= unlockAmount;

                if (userStake.amount == 0) {
                    if (userStakes.length > 1) {
                        userStakes[i] = userStakes[
                            userStakes.length - 1
                            ];
                    }
                    userStakes.pop();
                    if (userStakes.length == i) {
                        break;
                    }
                } else {
                    i++;
                }

                if (unlockedAmount == _withdrawAmount) {
                    return;
                }
            } else {
                i++;
            }

            if (unlockedAmount == _withdrawAmount) {
                return;
            }
        }

        require(
            unlockedAmount == _withdrawAmount,
            "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
        );
    }

    function _calculateUnlockableAmount(
        Stake memory _stake
    )
        private
        view
        returns (uint256)
    {
        if (block.timestamp >= _stake.unlockTime) {
            return _stake.amount;
        }

        uint256 unlockDuration = _stake.unlockTime
            - _stake.unlockTime;

        uint256 elapsedTime = _stake.unlockTime
            - block.timestamp;

        uint256 unlockableAmount = _stake.amount
            * elapsedTime
            / unlockDuration;

        return unlockableAmount;
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
        _unlock(
            _amount,
            msg.sender
        );

        stakes[_recipient].push(
            Stake(
                _amount,
                block.timestamp,
                block.timestamp
            )
        );

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

        _unlock(
            _amount,
            _sender
        );

        stakes[_recipient].push(
            Stake(
                _amount,
                block.timestamp,
                block.timestamp
            )
        );

        _transfer(
            _sender,
            _recipient,
            _amount
        );

        return true;
    }
}
