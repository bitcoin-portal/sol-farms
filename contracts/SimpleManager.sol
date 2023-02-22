// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.17;

interface SimpleFarm {

    function setRewardRate(
        uint256 newRate
    )
        external;
}

interface IERC20 {

    function transfer(
        address to,
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
            SimpleFarm(_targetFarms[i]).setRewardRate(
                _newRates[i]
            );
        }
    }

    function recoverToken(
        address tokenAddress,
        uint256 tokenAmount
    )
        external
    {
        IERC20(tokenAddress).transfer(
            owner,
            tokenAmount
        );
    }
}
