// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IBalancerV3Pool
 * @notice Interface for Balancer V3 Pool contract
 */
interface IBalancerV3Pool {
    function getTokens() external view returns (address[] memory);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getNormalizedWeights() external view returns (uint256[] memory);
}
