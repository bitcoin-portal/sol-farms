// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.17;

import "./SafeERC20.sol";

contract TokenWrapper is SafeERC20 {

    uint256 private _totalStaked;
    mapping(address => uint256) private _balances;

    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _totalStaked;
    }

    function balanceOf(
        address _walletAddress
    )
        public
        view
        returns (uint256)
    {
        return _balances[_walletAddress];
    }

    function _stake(
        uint256 _amount,
        address _address
    )
        internal
    {
        _totalStaked =
        _totalStaked + _amount;

        unchecked {
            _balances[_address] =
            _balances[_address] + _amount;
        }
    }

    function _withdraw(
        uint256 _amount,
        address _address
    )
        internal
    {
        unchecked {
            _totalStaked =
            _totalStaked - _amount;
        }

        _balances[_address] =
        _balances[_address] - _amount;
    }
}
