// SPDX-License-Identifier: --BCOM--

pragma solidity =0.8.23;

import "./SimpleFarm.sol";

contract FarmCodeCheck {

    function farmCodeHash()
        external
        pure
        returns (bytes32)
    {
        return keccak256(
            type(SimpleFarm).creationCode
        );
    }
}
