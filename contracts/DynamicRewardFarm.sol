// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./TokenWrapper.sol";

contract DynamicRewardFarm is TokenWrapper {

    IERC20 public stakeToken;

    uint256 public periodFinished;
    uint256 public rewardDuration;
    uint256 public lastUpdateTime;

    uint256 constant PRECISION = 1E18;

    address public ownerAddress;
    address public proposedOwner;
    address public managerAddress;

    IERC20[] public rewardTokens;
    uint256 public tokenCount;

    struct RewardData {
        uint256 rewardRate;
        uint256 perTokenStored;
        mapping(address => uint256) userRewards;
        mapping(address => uint256) perTokenPaid;
    }

    mapping(address => RewardData) public rewards;

    modifier onlyOwner() {
        require(
            msg.sender == ownerAddress,
            "DynamicRewardFarm: INVALID_OWNER"
        );
        _;
    }

    modifier onlyManager() {
        require(
            msg.sender == managerAddress,
            "DynamicRewardFarm: INVALID_MANAGER"
        );
        _;
    }

    modifier updateFarm() {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 rewardToken = rewardTokens[i];
            rewards[address(rewardToken)].perTokenStored = rewardPerToken(
                rewardToken
            );
        }
        lastUpdateTime = lastTimeRewardApplicable();
        _;
    }

    modifier updateUser() {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 rewardToken = rewardTokens[i];
            address tokenAddress = address(rewardToken);

            RewardData storage r = rewards[
                tokenAddress
            ];

            // Initialize perTokenPaid for new reward tokens
            if (r.perTokenPaid[msg.sender] == 0 && _balances[msg.sender] > 0) {
                r.perTokenPaid[msg.sender] = r.perTokenStored;
            }

            r.userRewards[msg.sender] = earnedByToken(
                rewardToken,
                msg.sender
            );

            r.perTokenPaid[msg.sender] = r.perTokenStored;
        }
        _;
    }

    modifier updateSender(
        address _sender
    ) {
        for (uint256 i = 0; i < rewardTokens.length; i++) {

            IERC20 rewardToken = rewardTokens[i];

            address tokenAddress = address(
                rewardToken
            );

            RewardData storage r = rewards[
                tokenAddress
            ];

            // Initialize perTokenPaid for new reward tokens
            if (r.perTokenPaid[_sender] == 0 && _balances[_sender] > 0) {
                r.perTokenPaid[_sender] = r.perTokenStored;
            }

            r.userRewards[_sender] = earnedByToken(
                rewardToken,
                _sender
            );

            r.perTokenPaid[_sender] = r.perTokenStored;
        }
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
        address indexed rewardToken,
        uint256 rewardRate,
        uint256 tokenAmount
    );

    event RewardPaid(
        address indexed user,
        address indexed rewardToken,
        uint256 tokenAmount
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

    function initialize(
        address _stakeToken,
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
            "DynamicRewardFarm: INVALID_DURATION"
        );

        require(
            rewardDuration == 0,
            "DynamicRewardFarm: ALREADY_INITIALIZED"
        );

        rewardDuration = _defaultDuration;

        name = _name;
        symbol = _symbol;

        stakeToken = IERC20(
            _stakeToken
        );

        ownerAddress = _ownerAddress;
        managerAddress = _managerAddress;
    }

    /**
     * @dev Adds a new reward token to the farm
     */
    function addRewardToken(
        address _rewardToken
    )
        external
        onlyManager
    {
        if (_rewardToken == ZERO_ADDRESS) {
            revert("DynamicRewardFarm: WRONG_ADDRESS");
        }

        // Ensure the reward token is not yet added
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (address(rewardTokens[i]) == _rewardToken) {
                revert("DynamicRewardFarm: TOKEN_ALREADY_ADDED");
            }
        }

        rewardTokens.push(
            IERC20(_rewardToken)
        );

        tokenCount++;
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
     * @dev Relative value on reward for single staked token for a given reward token
     */
    function rewardPerToken(
        IERC20 _rewardToken
    )
        public
        view
        returns (uint256)
    {
        if (_totalStaked == 0) {
            return rewards[address(_rewardToken)].perTokenStored;
        }

        uint256 timeFrame = lastTimeRewardApplicable()
            - lastUpdateTime;

        uint256 extraFund = timeFrame
            * rewards[address(_rewardToken)].rewardRate
            * PRECISION
            / _totalStaked;

        return rewards[address(_rewardToken)].perTokenStored
            + extraFund;
    }

    /**
     * @dev Returns an array of earned amounts for all reward tokens for the caller
     */
    function earned()
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory earnedAmounts = new uint256[](
            rewardTokens.length
        );

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            earnedAmounts[i] = earnedByToken(
                rewardTokens[i],
                msg.sender
            );
        }

        return earnedAmounts;
    }

    /**
     * @dev Reports earned amount of a reward token by wallet address not yet collected
     */
    function earnedByToken(
        IERC20 _rewardToken,
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        RewardData storage r = rewards[
            address(_rewardToken)
        ];

        uint256 perTokenPaidValue = r.perTokenPaid[
            _walletAddress
        ];

        // If perTokenPaid is zero and user has a balance,
        // assume they haven't started earning this reward
        if (perTokenPaidValue == 0 && _balances[_walletAddress] > 0) {
            return r.userRewards[_walletAddress];
        }

        uint256 difference = rewardPerToken(_rewardToken)
            - perTokenPaidValue;

        return _balances[_walletAddress]
            * difference
            / PRECISION
            + r.userRewards[_walletAddress];
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
            "DynamicRewardFarm: STILL_EARNING"
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
    {
        address senderAddress = msg.sender;

        for (uint256 i = 0; i < rewardTokens.length; i++) {

            IERC20 rewardToken = rewardTokens[i];

            address tokenAddress = address(
                rewardToken
            );

            RewardData storage r = rewards[
                tokenAddress
            ];

            uint256 rewardAmount = r.userRewards[
                senderAddress
            ];

            if (rewardAmount > 0) {
                r.userRewards[senderAddress] = 0;

                safeTransfer(
                    rewardToken,
                    senderAddress,
                    rewardAmount
                );

                emit RewardPaid(
                    senderAddress,
                    tokenAddress,
                    rewardAmount
                );
            }
        }
    }

    function proposeNewOwner(
        address _newOwner
    )
        external
        onlyOwner
    {
        if (_newOwner == ZERO_ADDRESS) {
            revert("DynamicRewardFarm: WRONG_ADDRESS");
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
            "DynamicRewardFarm: INVALID_CANDIDATE"
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
        if (_newManager == ZERO_ADDRESS) {
            revert("DynamicRewardFarm: WRONG_ADDRESS");
        }

        managerAddress = _newManager;

        emit ManagerChanged(
            _newManager
        );
    }

    function recoverToken(
        IERC20 _tokenAddress,
        uint256 _tokenAmount
    )
        external
        onlyOwner
    {
        if (address(_tokenAddress) == ZERO_ADDRESS) {
            revert("DynamicRewardFarm: WRONG_ADDRESS");
        }

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (address(_tokenAddress) == address(rewardTokens[i])) {
                revert("DynamicRewardFarm: REWARD_TOKEN");
            }
        }

        safeTransfer(
            _tokenAddress,
            ownerAddress,
            _tokenAmount
        );

        emit Recovered(
            _tokenAddress,
            _tokenAmount
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
            "DynamicRewardFarm: INVALID_DURATION"
        );

        require(
            block.timestamp > periodFinished,
            "DynamicRewardFarm: ONGOING_DISTRIBUTION"
        );

        rewardDuration = _rewardDuration;

        emit RewardsDurationUpdated(
            _rewardDuration
        );
    }

    function setRewardRates(
        IERC20[] calldata _rewardTokens,
        uint256[] calldata _newRewardRates
    )
        external
        onlyManager
        updateFarm()
    {
        require(
            _totalStaked > 0,
            "DynamicRewardFarm: NO_STAKERS"
        );

        require(
            _rewardTokens.length == _newRewardRates.length,
            "DynamicRewardFarm: ARRAY_LENGTH_MISMATCH"
        );

        uint256 currentPeriodFinish = periodFinished;

        lastUpdateTime = block.timestamp;
        periodFinished = block.timestamp + rewardDuration;

        if (block.timestamp < currentPeriodFinish) {

            uint256 remainingTime = currentPeriodFinish
                - block.timestamp;

            for (uint256 i = 0; i < _rewardTokens.length; i++) {

                IERC20 rewardToken = _rewardTokens[i];

                address tokenAddress = address(
                    rewardToken
                );

                RewardData storage r = rewards[
                    tokenAddress
                ];

                require(
                    r.rewardRate <= _newRewardRates[i],
                    "DynamicRewardFarm: RATE_CANT_DECREASE"
                );

                uint256 rewardRemains = remainingTime
                    * r.rewardRate;

                safeTransfer(
                    rewardToken,
                    managerAddress,
                    rewardRemains
                );

                r.rewardRate = _newRewardRates[i];

                uint256 newRewardAmount = rewardDuration
                    * _newRewardRates[i];

                safeTransferFrom(
                    rewardToken,
                    managerAddress,
                    address(this),
                    newRewardAmount
                );

                emit RewardAdded(
                    tokenAddress,
                    _newRewardRates[i],
                    newRewardAmount
                );
            }

            return;
        }

        uint256 totalRate;

        for (uint256 i = 0; i < _rewardTokens.length; i++) {

            IERC20 rewardToken = _rewardTokens[i];

            address tokenAddress = address(
                rewardToken
            );

            totalRate += _newRewardRates[i];
            rewards[tokenAddress].rewardRate = _newRewardRates[i];

            uint256 newRewardAmount = rewardDuration
                * _newRewardRates[i];

            safeTransferFrom(
                rewardToken,
                managerAddress,
                address(this),
                newRewardAmount
            );

            emit RewardAdded(
                tokenAddress,
                _newRewardRates[i],
                newRewardAmount
            );
        }

        require(
            totalRate > 0,
            "DynamicRewardFarm: INVALID_RATE"
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
