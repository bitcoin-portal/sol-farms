// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IERC20.sol";

/**
 * @title ISimpleFarm
 * @notice Interface for SimpleFarm contract
 */
interface ISimpleFarm {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function farmDeposit(uint256 amount) external;
    function farmWithdraw(uint256 amount) external;
    function initialize(
        address _stakeToken,
        address _rewardToken,
        uint256 _defaultDuration,
        address _owner,
        address _manager,
        string calldata _name,
        string calldata _symbol
    ) external;
    function setRewardRate(uint256 newRate) external;
    function rewardToken() external view returns (IERC20);
    function rewardDuration() external view returns (uint256);
}
