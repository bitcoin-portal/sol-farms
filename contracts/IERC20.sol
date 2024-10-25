// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

interface IERC20 {

    /**
     * @dev Interface fo transfer function
     */
    function transfer(
        address _recipient,
        uint256 _amount
    )
        external
        returns (bool);

    /**
     * @dev Interface for transferFrom function
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        external
        returns (bool);

    /**
     * @dev Interface for approve function
     */
    function approve(
        address _spender,
        uint256 _amount
    )
        external
        returns (bool);

    function balanceOf(
        address _account
    )
        external
        view
        returns (uint256);

    function mint(
        address _user,
        uint256 _amount
    )
        external;
}
