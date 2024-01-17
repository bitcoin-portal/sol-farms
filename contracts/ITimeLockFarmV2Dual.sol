// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.23;

interface ITimeLockFarmV2Dual {

    function makeDepositForUser(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        external;

    function stakeToken()
        external
        view
        returns (address);

    function rewardTokenB()
        external
        view
        returns (address);

    function setRewardRates(
        uint256 newRateA,
        uint256 newRateB
    )
        external;

    function setRewardDuration(
        uint256 newDuration
    )
        external;
}