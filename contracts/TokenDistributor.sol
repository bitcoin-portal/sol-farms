// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./SafeERC20.sol";

contract TokenDistributor is SafeERC20 {

    address public owner;
    address public token;
    address public manager;

    uint256 public coolDown;
    address public proposedOwner;

    bool enableCoolDown = false;
    mapping(address => uint256) public lastDistributed;

    constructor() {
        owner = msg.sender;
        manager = msg.sender;
        coolDown = 2 minutes;
    }

    event Received(
        address indexed sender,
        uint256 value
    );

    receive ()
        external
        payable
    {
        emit Received(
            msg.sender,
            msg.value
        );
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "TokenDistributor: INVALID_OWNER"
        );
        _;
    }

    modifier onlyManager {
        require(
            msg.sender == manager,
            "TokenDistributor: INVALID_MANAGER"
        );
        _;
    }

    function changeManager(
        address _manager
    )
        external
        onlyOwner
    {
        manager = _manager;
    }

    function proposeOwner(
        address _owner
    )
        external
        onlyOwner
    {
        proposedOwner = _owner;
    }

    function acceptOwnership()
        external
    {
        require(
            msg.sender == proposedOwner,
            "TokenDistributor: INVALID_CALLER"
        );

        owner = proposedOwner;
        proposedOwner = address(0x0);
    }

    function defineToken(
        address _token
    )
        external
        onlyOwner
    {
        token = _token;
    }

    function defineCoolDown(
        uint256 _coolDown
    )
        external
        onlyOwner
    {
        coolDown = _coolDown;
    }

    function setLastDistributed(
        address _recipient,
        uint256 _time
    )
        external
        onlyOwner
    {
        lastDistributed[_recipient] = _time;
    }

    function changeEnableCoolDown(
        bool _enableCoolDown
    )
        external
        onlyOwner
    {
        enableCoolDown = _enableCoolDown;
    }

    function sendNative(
        address[] calldata _recipients,
        uint256[] calldata _amounts
    )
        external
        onlyManager
    {
        require(
            _recipients.length == _amounts.length,
            "TokenDistributor: INVALID_INPUT"
        );

        for (uint256 i; i < _recipients.length; i++) {

            if (enableCoolDown == false) {
                payable(_recipients[i]).transfer(
                    _amounts[i]
                );

                continue;
            }

            if (lastDistributed[_recipients[i]] + coolDown > block.timestamp) {
                continue;
            }

            lastDistributed[_recipients[i]] = block.timestamp;

            payable(_recipients[i]).transfer(
                _amounts[i]
            );
        }
    }

    function sendTokens(
        address[] calldata _recipients,
        uint256[] calldata _amounts
    )
        external
        onlyManager
    {
        require(
            _recipients.length == _amounts.length,
            "TokenDistributor: INVALID_INPUT"
        );

        for (uint256 i; i < _recipients.length; i++) {

            if (enableCoolDown == false) {

                safeTransfer(
                    IERC20(token),
                    _recipients[i],
                    _amounts[i]
                );

                continue;
            }

            if (lastDistributed[_recipients[i]] + coolDown > block.timestamp) {
                continue;
            }

            lastDistributed[_recipients[i]] = block.timestamp;

            safeTransfer(
                IERC20(token),
                _recipients[i],
                _amounts[i]
            );
        }
    }
}
