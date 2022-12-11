// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.17;

interface IERC20 {

    function transfer(
        address recipient,
        uint256 amount
    )
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        returns (bool);
}
