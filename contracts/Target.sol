// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

interface Target {

    function changeManager(
        address _newManager
    )
        external;

    function proposeNewOwner(
        address _newOwner
    )
        external;
}
