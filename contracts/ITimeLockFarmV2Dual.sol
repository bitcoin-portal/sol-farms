// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.25;

interface ITimeLockFarmV2Dual {

    function makeDepositForUser(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        external;

    function totalSupply()
        external
        view
        returns (uint256);

    function stakeToken()
        external
        view
        returns (address);

    function setRewardRates(
        uint256 newRateA,
        uint256 newRateB
    )
        external;

    function claimOwnership()
        external;

    function rewardTokenA()
        external
        view
        returns (address);

    function rewardTokenB()
        external
        view
        returns (address);

    function proposeNewOwner(
        address _newOwner
    )
        external;

    function destroyStaker(
        bool _allowFarmWithdraw,
        bool _allowClaimRewards,
        address _withdrawAddress
    )
        external;

    function setRewardDuration(
        uint256 newDuration
    )
        external;

    function balanceOf(
        address _stakeOwner
    )
        external
        view
        returns (uint256);

    function unlockable(
        address _stakeOwner
    )
        external
        view
        returns (uint256);

    function farmWithdraw(
        uint256 _amount
    )
        external;

    function exitFarm()
        external;

    function claimReward()
        external;

    function earnedA(
        address _stakeOwner
    )
        external
        view
        returns (uint256);

    function earnedB(
        address _stakeOwner
    )
        external
        view
        returns (uint256);

    function recoverTokens(
        address _tokenAddress,
        uint256 _tokenAmount
    )
        external;

    function sponsorInitialRewardA(
        address _walletAddress,
        uint256 _rewardAmountA
    )
        external;

    function sponsorInitialRewardB(
        address _walletAddress,
        uint256 _rewardAmountB
    )
        external;

    function changeManager(
        address _newManager
    )
        external;
}