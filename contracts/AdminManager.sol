// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./Target.sol";

contract AdminManager {

    address public multiSignature;
    address public proposedTarget;
    address public proposedManager;

    modifier onlyMultiSignature() {
        require(
            msg.sender == multiSignature,
            "AdminManager: INVALID_CALLER"
        );
        _;
    }

    modifier onlyProposedManager() {
        require(
            msg.sender == proposedManager,
            "AdminManager: INVALID_CALLER"
        );
        _;
    }

    function proposeManagerOnTarget(
        address _target,
        address _newManager
    )
        external
        onlyMultiSignature
    {
        proposedTarget = _target;
        proposedManager = _newManager;
    }

    function changeManagerOnTarget()
        external
        onlyProposedManager
    {
        Target target = Target(
            proposedTarget
        );

        target.changeManager(
            proposedManager
        );

        proposedTarget = address(0x0);
        proposedManager = address(0x0);
    }
}
