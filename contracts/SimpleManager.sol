// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.17;

interface SimpleFarm {

    function setRewardRate(
        uint256 newRate
    )
        external;

    function rewardToken()
        external
        view
        returns (IERC20);

    function rewardDuration()
        external
        view
        returns (uint256);
}

interface IERC20 {

    function transfer(
        address to,
        uint256 amount
    )
        external
        returns (bool);

    function approve(
        address spender,
        uint256 amount
    )
        external
        returns (bool);
}

contract SimpleManager {

    address public owner;
    address public worker;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "SimpleManager: NOT_OWNER"
        );
        _;
    }

    modifier onlyWorker() {
        require(
            msg.sender == worker,
            "SimpleManager: NOT_WORKER"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
        worker = msg.sender;
    }

    function changeWorker(
        address _newWorker
    )
        external
        onlyOwner
    {
        worker = _newWorker;
    }

    function manageRates(
        address[] calldata _targetFarms,
        uint256[] calldata _newRates
    )
        external
        onlyWorker
    {
        for (uint256 i = 0; i < _targetFarms.length; i++) {

            SimpleFarm farm = SimpleFarm(
                _targetFarms[i]
            );

            IERC20 rewardToken = farm.rewardToken();
            uint256 rewardDuration = farm.rewardDuration();

            rewardToken.approve(
                _targetFarms[i],
                _newRates[i] * rewardDuration
            );

            farm.setRewardRate(
                _newRates[i]
            );
        }
    }

    function recoverToken(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
    {
        tokenAddress.transfer(
            owner,
            tokenAmount
        );
    }
}
