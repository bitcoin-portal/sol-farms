// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.17;

import "./SafeERC20.sol";

contract TokenWrapper is SafeERC20 {

    string public name = "VerseFarm";
    string public symbol = "VFARM";

    uint8 public decimals = 18;

    uint256 _totalStaked;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 value
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply()
        external
        view
        returns (uint256)
    {
        return _totalStaked;
    }

    function balanceOf(
        address _walletAddress
    )
        external
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

    function transfer(
        address _recipient,
        uint256 _amount
    )
        external
        returns (bool)
    {
        _transfer(
            msg.sender,
            _recipient,
            _amount
        );

        return true;
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        internal
    {
        _balances[_sender] =
        _balances[_sender] - _amount;

        unchecked {
            _balances[_recipient] =
            _balances[_recipient] + _amount;
        }

        emit Transfer(
            _sender,
            _recipient,
            _amount
        );
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        external
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

    function approve(
        address _spender,
        uint256 _amount
    )
        external
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            _amount
        );

        return true;
    }

    function allowance(
        address _owner,
        address _spender
    )
        external
        view
        returns (uint256)
    {
        return _allowances[_owner][_spender];
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    )
        internal
    {
        _allowances[_owner][_spender] = _amount;

        emit Approval(
            _owner,
            _spender,
            _amount
        );
    }

    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    )
        external
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            _allowances[msg.sender][_spender] + _addedValue
        );

        return true;
    }

    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    )
        external
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            _allowances[msg.sender][_spender] - _subtractedValue
        );

        return true;
    }
}
