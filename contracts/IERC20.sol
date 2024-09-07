// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.25;

interface IERC20 {

    /**
     * @dev Interface fo transfer function
     */
    function transfer(
        address recipient,
        uint256 amount
    )
        external
        returns (bool);

    /**
     * @dev Interface for transferFrom function
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        returns (bool);

    /**
     * @dev Interface for approve function
     */
    function approve(
        address spender,
        uint256 amount
    )
        external
        returns (bool);

    function balanceOf(
        address account
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
