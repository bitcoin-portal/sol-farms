// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./TokenWrapper.sol";

error NoRewards();
error UnknownToken();
error ExistingToken();
error InvalidAddress();

contract DynamicRewardFarm is TokenWrapper {

    IERC20 public stakeToken;

    uint256 public periodFinished;
    uint256 public rewardDuration;
    uint256 public lastUpdateTime;

    uint256 constant MAX_TOKENS = 10;
    uint256 constant PRECISIONS = 1E18;

    address public ownerAddress;
    address public proposedOwner;
    address public managerAddress;

    uint256 public tokenCount;
    address[] public rewardTokens;

    address constant DEAD_ADDRESS = address(
        0x000000000000000000000000000000000000dEaD
    );

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
        _updateFarm();
        _;
    }

    modifier updateUser() {
        _updateUser(msg.sender);
        _;
    }

    modifier updateSender(address _sender) {
        _updateUser(_sender);
        _;
    }

    /**
     * @dev This is desired because this contract is
     * cloned by the factory contract calling initialize
     */
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

        _stake(
            PRECISIONS,
            DEAD_ADDRESS
        );
    }

    /**
     * @dev Adds a new reward token to the farm
     */
    function addRewardToken(
        address _rewardToken
    )
        external
        onlyOwner
    {
        require(
            tokenCount < MAX_TOKENS,
            "DynamicRewardFarm: MAX_TOKENS_REACHED"
        );

        _validateRewardToken(
            _rewardToken
        );

        rewardTokens.push(
            _rewardToken
        );

        tokenCount = tokenCount + 1;
    }

    /**
     * @dev Checks if the token is already added
     */
    function _validateRewardToken(
        address _tokenAddress
    )
        private
        view
    {
        if (_tokenAddress == ZERO_ADDRESS) {
            revert InvalidAddress();
        }

        for (uint256 i; i < rewardTokens.length; i++) {
            if (_tokenAddress == rewardTokens[i]) {
                revert ExistingToken();
            }
        }
    }

    function getRewardTokens()
        external
        view
        returns (address[] memory)
    {
        address[] memory tokens = new address[](
            rewardTokens.length
        );

        for (uint256 i; i < rewardTokens.length; i++) {
            tokens[i] = rewardTokens[i];
        }

        return tokens;
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
     * @dev Relative value on reward for single
     * staked token for a given {_rewardToken}
     */
    function rewardPerToken(
        address _rewardToken
    )
        public
        view
        returns (uint256)
    {
        if (_totalStaked == 0) {
            return rewards[_rewardToken].perTokenStored;
        }

        RewardData storage r = rewards[
            _rewardToken
        ];

        uint256 timeFrame = lastTimeRewardApplicable()
            - lastUpdateTime;

        uint256 extraFund = timeFrame
            * r.rewardRate
            * PRECISIONS
            / _totalStaked;

        return r.perTokenStored
            + extraFund;
    }

    /**
     * @dev Returns an array of earned amounts for
     * all reward tokens by given {_walletAddress}
     */
    function earned(
        address _walletAddress
    )
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory earnedAmounts = new uint256[](
            rewardTokens.length
        );

        for (uint256 i; i < rewardTokens.length; i++) {
            earnedAmounts[i] = earnedByToken(
                rewardTokens[i],
                _walletAddress
            );
        }

        return earnedAmounts;
    }

    /**
     * @dev Reports earned amount of a reward
     * token by wallet address not yet collected
     */
    function earnedByToken(
        address _rewardToken,
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        RewardData storage r = rewards[
            _rewardToken
        ];

        uint256 difference = rewardPerToken(_rewardToken)
            - r.perTokenPaid[_walletAddress];

        return _balances[_walletAddress]
            * difference
            / PRECISIONS
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

        for (uint256 i; i < rewardTokens.length; i++) {

            address tokenAddress = rewardTokens[i];

            RewardData storage r = rewards[
                tokenAddress
            ];

            uint256 rewardAmount = earnedByToken(
                tokenAddress,
                senderAddress
            );

            if (rewardAmount > 0) {

                r.userRewards[senderAddress] = 0;

                safeTransfer(
                    IERC20(tokenAddress),
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
            revert("DynamicRewardFarm: ZERO_ADDRESS");
        }

        managerAddress = _newManager;

        emit ManagerChanged(
            _newManager
        );
    }

    function recoverToken(
        address _tokenAddress,
        uint256 _recoveryAmount
    )
        external
        onlyOwner
    {
        IERC20 tokenAddress = IERC20(
            _tokenAddress
        );

        if (tokenAddress == stakeToken) {
            revert("DynamicRewardFarm: STAKE_TOKEN");
        }

        for (uint256 i; i < rewardTokens.length; i++) {
            if (_tokenAddress == rewardTokens[i]) {

                uint256 earnedByDead = earnedByToken(
                    _tokenAddress,
                    DEAD_ADDRESS
                );

                require(
                    _recoveryAmount <= earnedByDead,
                    "DynamicRewardFarm: NOT_ENOUGH_REWARDS"
                );

                _updateUser(DEAD_ADDRESS);

                rewards[_tokenAddress].userRewards[DEAD_ADDRESS] =
                rewards[_tokenAddress].userRewards[DEAD_ADDRESS] - _recoveryAmount;

                break;
            }
        }

        safeTransfer(
            tokenAddress,
            ownerAddress,
            _recoveryAmount
        );

        emit Recovered(
            tokenAddress,
            _recoveryAmount
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

    function _onlyExistingToken(
        address _tokenAddress
    )
        private
        view
    {
        for (uint256 i; i < rewardTokens.length; i++) {
            if (_tokenAddress == rewardTokens[i]) {
                return;
            }
        }

        revert UnknownToken();
    }

    /**
     * @dev Internal function to set reward rate for a token
     */
    function _setRewardRate(
        address _rewardToken,
        uint256 _newRewardRate
    )
        private
    {
        _onlyExistingToken(
            _rewardToken
        );

        IERC20 tokenAddress = IERC20(
            _rewardToken
        );

        RewardData storage r = rewards[
            _rewardToken
        ];

        if (block.timestamp < periodFinished) {

            require(
                r.rewardRate <= _newRewardRate,
                "DynamicRewardFarm: RATE_CANT_DECREASE"
            );

            uint256 remainingTime = periodFinished
                - block.timestamp;

            uint256 remainingRewards = remainingTime
                * r.rewardRate;

            safeTransfer(
                tokenAddress,
                managerAddress,
                remainingRewards
            );
        }

        r.rewardRate = _newRewardRate;

        uint256 newRewardAmount = rewardDuration
            * _newRewardRate;

        safeTransferFrom(
            tokenAddress,
            managerAddress,
            address(this),
            newRewardAmount
        );

        emit RewardAdded(
            _rewardToken,
            _newRewardRate,
            newRewardAmount
        );
    }

    /**
     * @dev Sets the reward rates for multiple reward tokens
     */
    function setRewardRates(
        address[] calldata _rewardTokens,
        uint256[] calldata _newRewardRates
    )
        external
        onlyManager
        updateFarm()
    {
        require(
            _rewardTokens.length == _newRewardRates.length,
            "DynamicRewardFarm: ARRAY_LENGTH_MISMATCH"
        );

        require(
            _rewardTokens.length == rewardTokens.length,
            "DynamicRewardFarm: TOKEN_LENGTH_MISMATCH"
        );

        _shouldHaveSomeRewards(
            _newRewardRates
        );

        for (uint256 i; i < _rewardTokens.length; i++) {
            _setRewardRate(
                _rewardTokens[i],
                _newRewardRates[i]
            );
        }

        lastUpdateTime = block.timestamp;
        periodFinished = block.timestamp + rewardDuration;
    }

    /**
     * @dev Checks if there are any rewards to distribute
     */
    function _shouldHaveSomeRewards(
        uint256[] calldata _newRewardRates
    )
        private
        pure
    {
        for (uint256 i; i < _newRewardRates.length; i++) {
            if (_newRewardRates[i] > 0) {
                return;
            }
        }

        revert NoRewards();
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

    function _updateFarm()
        private
    {
        for (uint256 i; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            rewards[rewardToken].perTokenStored = rewardPerToken(
                rewardToken
            );
        }

        lastUpdateTime = lastTimeRewardApplicable();
    }

    function _updateUser(
        address _user
    )
        private
    {
        for (uint256 i; i < rewardTokens.length; i++) {

            address tokenAddress = rewardTokens[i];

            RewardData storage r = rewards[
                tokenAddress
            ];

            r.userRewards[_user] = earnedByToken(
                tokenAddress,
                _user
            );

            r.perTokenPaid[_user] = r.perTokenStored;
        }
    }
}
