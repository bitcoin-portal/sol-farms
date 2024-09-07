// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.25;

interface SimpleFarm {

    function initialize(
        address _stakeToken,
        address _rewardToken,
        uint256 _defaultDuration,
        address _owner,
        address _manager
    )
        external;
}

contract FarmFactory {

    address constant ZERO_ADDRESS = address(0x0);
    address public immutable IMPLEMENTATION_TARGET;

    event FarmCreated(
        address indexed farm,
        address indexed owner
    );

    constructor(
        address _implementationTarget
    )
    {
        IMPLEMENTATION_TARGET = address(
            _implementationTarget
        );
    }

    function createFarm(
        address _stakeToken,
        address _rewardToken,
        uint256 _defaultDuration
    )
        external
        returns (address)
    {
        return _clone(
            _stakeToken,
            _rewardToken,
            _defaultDuration
        );
    }

    function _clone(
        address _stakeToken,
        address _rewardToken,
        uint256 _defaultDuration
    )
        private
        returns (address simpleFarm)
    {
        bytes32 salt = keccak256(
            abi.encodePacked(
                _stakeToken,
                _rewardToken,
                _defaultDuration,
                block.timestamp
            )
        );

        bytes20 targetBytes = bytes20(
            IMPLEMENTATION_TARGET
        );

        assembly {

            let clone := mload(0x40)

            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )

            mstore(
                add(clone, 0x14),
                targetBytes
            )

            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )

            simpleFarm := create2(
                0,
                clone,
                0x37,
                salt
            )
        }

        SimpleFarm(simpleFarm).initialize(
            _stakeToken,
            _rewardToken,
            _defaultDuration,
            msg.sender,
            msg.sender
        );

        emit FarmCreated(
            simpleFarm,
            msg.sender
        );
    }
}
