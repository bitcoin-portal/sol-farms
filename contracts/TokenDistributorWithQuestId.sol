// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./SafeERC20.sol";

contract TokenDistributorWithQuestId is SafeERC20 {

    address public owner;
    address public token;
    address public manager;

    address public proposedOwner;

    mapping(address => mapping(string => bool)) public distributed;

    constructor() {
        owner = msg.sender;
        manager = msg.sender;
    }

    event AlreadyDistributed(
        address indexed recipient,
        string indexed questId
    );

    event Distributed(
        address indexed recipient,
        uint256 value,
        string indexed questId
    );

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
            payable(_recipients[i]).transfer(_amounts[i]);
        }
    }

    function sendTokens(
        address[] calldata _recipients,
        uint256[] calldata _amounts,
        string[] calldata _questIds
    )
        external
        onlyManager
    {
        require(
            _recipients.length == _amounts.length,
            "TokenDistributor: INVALID_INPUT"
        );

        require(
            _amounts.length == _questIds.length,
            "TokenDistributor: INVALID_INPUT"
        );

        for (uint256 i; i < _recipients.length; i++) {

            address _recipient = _recipients[i];
            uint256 _amount = _amounts[i];
            string memory _questId = _questIds[i];


            if (distributed[_recipient][_questId] == true) {

                emit AlreadyDistributed(
                    _recipient,
                    _questId
                );

                continue;
            }

            distributed[_recipient][_questId] = true;

            safeTransfer(
                IERC20(token),
                _recipient,
                _amount
            );

            emit Distributed(
                _recipient,
                _amount,
                _questId
            );
        }
    }
}