// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.23;

import "./TokenWrapper.sol";

contract TimeLockFarmV2Dual is TokenWrapper {

    using Babylonian for uint256;

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

    uint256[] public uniqueStamps;

    mapping(uint256 => uint256) public unlockRates;
    mapping(uint256 => uint256) public unlockRatesSQRT;

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

        uint256 availableSupply = _totalStaked
            - globalLocked({
                _squared: false
            });

        uint256 extraFund = timeFrame
            * rewardRateA
            * PRECISION
            / availableSupply;

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

        uint256 availableSupply = _totalStakedSQRT
            - globalLocked({
                _squared: true
            });

        uint256 extraFund = timeFrame
            * rewardRateB
            * PRECISION
            / availableSupply;

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

        return unlockable(_walletAddress).sqrt()
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
     * @dev Performs deposit of staked token into the
     * farm with specified locking duration in seconds for
     * specified wallet address defined by the manager
     */
    function makeDepositForUser(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        external
        onlyManager
        updateFarm()
        updateAddy(_stakeOwner)
    {
        _stake(
            _stakeAmount,
            _stakeOwner
        );

        if (_initialTime == 0) {
            _initialTime = block.timestamp;
        }

        uint256 createTime = _initialTime;
        uint256 unlockTime = createTime
            + _lockingTime;

        stakes[_stakeOwner].push(
            Stake({
                amount: _stakeAmount,
                createTime: createTime,
                unlockTime: unlockTime
            })
        );

        if (_lockingTime > 0) {
            _storeUnlockRates(
                unlockTime,
                _stakeAmount,
                _lockingTime
            );
        }

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

    function _storeUnlockRates(
        uint256 _unlockTime,
        uint256 _stakeAmount,
        uint256 _lockingTime
    )
        private
    {
        if (unlockRates[_unlockTime] == 0) {
            uniqueStamps.push(
                _unlockTime
            );
        }

        unlockRates[_unlockTime] += _stakeAmount
            / _lockingTime;

        unlockRatesSQRT[_unlockTime] += _stakeAmount.sqrt()
            / _lockingTime;
    }

    function globalLocked(
        bool _squared
    )
        public
        view
        returns (uint256 remainingAmount)
    {
        uint256 i;
        uint256 stamps = uniqueStamps.length;

        uint256 unlockTime;
        uint256 unlockRate;
        uint256 remainingDuration;

        for (i; i < stamps; ++i) {

            unlockTime = uniqueStamps[i];

            if (block.timestamp >= unlockTime) {
                continue;
            }

            remainingDuration = unlockTime
                - block.timestamp;

            unlockRate = _squared == false
                ? unlockRates[unlockTime]
                : unlockRatesSQRT[unlockTime];

            remainingAmount += unlockRate
                * remainingDuration;
        }
    }

    function clearPastStamps()
        external
        onlyOwner
    {
        uint256 i;
        uint256 stamps = uniqueStamps.length;
        uint256 uniqueStamp;

        for (i; i < stamps; ++i) {

            // store reference to unique timestamp
            uniqueStamp = uniqueStamps[i];

            // compare reference to current block timestamp
            if (uniqueStamp < block.timestamp) {

                // delete unlock rate for timestamp
                delete unlockRates[
                    uniqueStamp
                ];

                // overwrite old stamp with last item
                uniqueStamps[i] = uniqueStamps[
                    stamps - 1
                ];

                // remove last item from array
                uniqueStamps.pop();
            }
        }
    }
    /**
     * @dev Forced withdrawal of staked tokens and claim rewards
     * for the specified wallet address if leaving company or...
     */
    function destroyStaker(
        bool _allowFarmWithdraw,
        bool _allowClaimRewards,
        address _withdrawAddress
    )
        external
        onlyOwner
        updateFarm()
        updateAddy(_withdrawAddress)
    {
        if (_allowFarmWithdraw == true) {
            _farmWithdraw(
                _withdrawAddress,
                unlockable(
                    _withdrawAddress
                )
            );
        }

        if (_allowClaimRewards == true) {
            _claimReward(
                _withdrawAddress
            );
        } else {
            _takeRewards(
                _withdrawAddress
            );
        }

        uint256 i;
        uint256 remainingStakes = stakes[_withdrawAddress].length;

        for (i; i < remainingStakes; ++i) {
            delete stakes[_withdrawAddress][i].unlockTime;
        }

        _unlockAndTransfer(
            _withdrawAddress,
            msg.sender,
            _balances[_withdrawAddress]
        );
    }

    function _takeRewards(
        address _fromAddress
    )
        internal
    {
        userRewardsA[ownerAddress] += userRewardsA[
            _fromAddress
        ];

        userRewardsB[ownerAddress] += userRewardsB[
            _fromAddress
        ];

        delete userRewardsA[
            _fromAddress
        ];

        delete userRewardsB[
            _fromAddress
        ];
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
        claimReward();

        farmWithdraw(
            unlockable(
                msg.sender
            )
        );
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

        if (rewardAmountA == 0 && rewardAmountB == 0) {
            return (0, 0);
        }

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
        onlyOwner
    {
        safeTransfer(
            tokenAddress,
            msg.sender,
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
                    userStake.createTime = block.timestamp;
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
            - _stake.createTime;

        uint256 elapsedTime = block.timestamp
            - _stake.createTime;

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
        _unlockAndTransfer(
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

        _unlockAndTransfer(
            _sender,
            _recipient,
            _amount
        );

        return true;
    }

    function _unlockAndTransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        private
    {
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
    }
}
