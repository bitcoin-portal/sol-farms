// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./TokenWrapper.sol";

contract DualRewardFarm is TokenWrapper {

    IERC20 public stakeToken;
    IERC20 public rewardTokenA;
    IERC20 public rewardTokenB;

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
            "DualRewardFarm: INVALID_OWNER"
        );
        _;
    }

    modifier onlyManager() {
        require(
            msg.sender == managerAddress,
            "DualRewardFarm: INVALID_MANAGER"
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
        userRewardsA[msg.sender] = earnedA(msg.sender);
        userRewardsB[msg.sender] = earnedB(msg.sender);
        perTokenPaidA[msg.sender] = perTokenStoredA;
        perTokenPaidB[msg.sender] = perTokenStoredB;
        _;
    }

    modifier updateSender(
        address _sender
    ) {
        userRewardsA[_sender] = earnedA(_sender);
        userRewardsB[_sender] = earnedB(_sender);
        perTokenPaidA[_sender] = perTokenStoredA;
        perTokenPaidB[_sender] = perTokenStoredB;
        _;
    }

    event RewardsAdded(
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

    function initialize(
        address _stakeToken,
        address _rewardTokenA,
        address _rewardTokenB,
        uint256 _defaultDuration,
        address _ownerAddress,
        address _managerAddress,
        string calldata _name,
        string calldata _symbol
    )
        external
    {
        require(
            _defaultDuration > 0,
            "DualRewardFarm: INVALID_DURATION"
        );

        require(
            rewardDuration == 0,
            "DualRewardFarm: ALREADY_INITIALIZED"
        );

        rewardDuration = _defaultDuration;

        name = _name;
        symbol = _symbol;

        stakeToken = IERC20(
            _stakeToken
        );

        rewardTokenA = IERC20(
            _rewardTokenA
        );

        rewardTokenB = IERC20(
            _rewardTokenB
        );

        ownerAddress = _ownerAddress;
        managerAddress = _managerAddress;
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
     * @dev Relative value on reward for single staked token for token A
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

        return perTokenStoredA + extraFund;
    }

    /**
     * @dev Relative value on reward for single staked token for token B
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
            / _totalStaked;

        return perTokenStoredB + extraFund;
    }

    /**
     * @dev Reports earned amount of token A by wallet address not yet collected
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
     * @dev Reports earned amount of token B by wallet address not yet collected
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

        return _balances[_walletAddress]
            * difference
            / PRECISION
            + userRewardsB[_walletAddress];
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

    function farmWithdraw(
        uint256 _withdrawAmount
    )
        public
        updateFarm()
        updateUser()
    {
        require(
            _totalStaked > _withdrawAmount ||
            block.timestamp > periodFinished,
            "DualRewardFarm: STILL_EARNING"
        );

        address senderAddress = msg.sender;

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

    function exitFarm()
        external
    {
        uint256 withdrawAmount = _balances[
            msg.sender
        ];

        farmWithdraw(
            withdrawAmount
        );

        claimRewards();
    }

    function claimRewards()
        public
        updateFarm()
        updateUser()
        returns (
            uint256 rewardAmountA,
            uint256 rewardAmountB
        )
    {
        address senderAddress = msg.sender;

        rewardAmountA = earnedA(
            senderAddress
        );

        rewardAmountB = earnedB(
            senderAddress
        );

        require(
            rewardAmountA > 0 ||
            rewardAmountB > 0,
            "DualRewardFarm: NOTHING_TO_CLAIM"
        );

        userRewardsA[senderAddress] = 0;
        userRewardsB[senderAddress] = 0;

        if (rewardAmountA > 0) {
            safeTransfer(
                rewardTokenA,
                senderAddress,
                rewardAmountA
            );
        }

        if (rewardAmountB > 0) {
            safeTransfer(
                rewardTokenB,
                senderAddress,
                rewardAmountB
            );
        }

        emit RewardPaid(
            senderAddress,
            rewardAmountA,
            rewardAmountB
        );
    }

    function proposeNewOwner(
        address _newOwner
    )
        external
        onlyOwner
    {
        if (_newOwner == ZERO_ADDRESS) {
            revert("DualRewardFarm: WRONG_ADDRESS");
        }

        proposedOwner = _newOwner;

        emit OwnerProposed(
            _newOwner
        );
    }

    function claimOwnership()
        external
    {
        require(
            msg.sender == proposedOwner,
            "DualRewardFarm: INVALID_CANDIDATE"
        );

        ownerAddress = proposedOwner;

        emit OwnerChanged(
            ownerAddress
        );
    }

    function changeManager(
        address _newManager
    )
        external
        onlyOwner
    {
        require(
            _newManager != ZERO_ADDRESS,
            "DualRewardFarm: WRONG_ADDRESS"
        );

        managerAddress = _newManager;

        emit ManagerChanged(
            _newManager
        );
    }

    function recoverToken(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
    {
        require(
            tokenAddress != stakeToken &&
            tokenAddress != rewardTokenA &&
            tokenAddress != rewardTokenB,
            "DualRewardFarm: INVALID_TOKEN"
        );

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

    function setRewardDuration(
        uint256 _rewardDuration
    )
        external
        onlyManager
    {
        require(
            _rewardDuration > 0,
            "DualRewardFarm: INVALID_DURATION"
        );

        require(
            block.timestamp > periodFinished,
            "DualRewardFarm: ONGOING_DISTRIBUTION"
        );

        rewardDuration = _rewardDuration;

        emit RewardsDurationUpdated(
            _rewardDuration
        );
    }

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
            "DualRewardFarm: NO_STAKERS"
        );

        require(
            _newRewardRateA > 0,
            "DualRewardFarm: INVALID_RATE_A"
        );

        require(
            _newRewardRateB > 0,
            "DualRewardFarm: INVALID_RATE_B"
        );

        uint256 currentPeriodFinish = periodFinished;

        lastUpdateTime = block.timestamp;
        periodFinished = block.timestamp + rewardDuration;

        if (block.timestamp < currentPeriodFinish) {

            require(
                _newRewardRateA >= rewardRateA,
                "DualRewardFarm: RATE_A_CANT_DECREASE"
            );

            require(
                _newRewardRateB >= rewardRateB,
                "DualRewardFarm: RATE_B_CANT_DECREASE"
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

        emit RewardsAdded(
            rewardRateA,
            rewardRateB,
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