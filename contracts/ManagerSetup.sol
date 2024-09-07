// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.25;

import "./SafeERC20.sol";
import "./ITimeLockFarmV2Dual.sol";

contract ManagerSetup is SafeERC20 {

    IERC20 public immutable VERSE;
    IERC20 public immutable STABLECOIN;

    address public owner;
    address public worker;

    ITimeLockFarmV2Dual public immutable TIME_LOCK_FARM;

    bool public isInitialized;

    mapping(address => bool) public isAllocationExecuted;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "ManagerSetup: NOT_OWNER"
        );
        _;
    }

    modifier onlyWorker() {
        require(
            msg.sender == worker,
            "ManagerSetup: NOT_WORKER"
        );
        _;
    }

    constructor(
        address _owner,
        address _worker,
        address _timeLockFarm
    ) {
        TIME_LOCK_FARM = ITimeLockFarmV2Dual(
            _timeLockFarm
        );

        owner = _owner;
        worker = _worker;

        VERSE = IERC20(
            TIME_LOCK_FARM.stakeToken()
        );

        STABLECOIN = IERC20(
            TIME_LOCK_FARM.rewardTokenB()
        );

        VERSE.approve(
            address(TIME_LOCK_FARM),
            type(uint256).max
        );

        STABLECOIN.approve(
            address(TIME_LOCK_FARM),
            type(uint256).max
        );
    }

    function makeApproval(
        IERC20 _token,
        address _spender,
        uint256 _amount
    )
        external
        onlyOwner
    {
        _token.approve(
            _spender,
            _amount
        );
    }

    function claimOwnershipAnyFarm(
        address _farm
    )
        external
        onlyOwner
    {
        ITimeLockFarmV2Dual(_farm).claimOwnership();
    }

    function proposeNewOwnerAnyFarm(
        address _farm,
        address _newOwner
    )
        external
        onlyOwner
    {
        ITimeLockFarmV2Dual(
            _farm
        ).proposeNewOwner(
            _newOwner
        );
    }

    function changeManagerAnyFarm(
        address _farm,
        address _newManager
    )
        external
        onlyOwner
    {
        ITimeLockFarmV2Dual(
            _farm
        ).changeManager(
            _newManager
        );
    }

    /**
     * @dev Sets the owner of the contract.
     * Owner can perform only certain actions.
     */
    function setOwner(
        address _newOwner
    )
        external
        onlyOwner
    {
        owner = _newOwner;
    }

    /**
     * @dev Sets the worker of the contract.
     * Worker can perform only certain actions.
     */
    function setWorker(
        address _newWorker
    )
        external
        onlyOwner
    {
        worker = _newWorker;
    }

    /**
     * @dev Sets the reward rates for the
     * private farm contract only by worker
     */
    function setRewardRates(
        uint256 _newRateA,
        uint256 _newRateB
    )
        external
        onlyWorker
    {
        TIME_LOCK_FARM.setRewardRates(
            _newRateA,
            _newRateB
        );
    }

    /**
     * @dev Sets the reward duration for the
     * private farm contract only by worker
     */
    function setRewardDuration(
        uint256 _newDuration
    )
        external
        onlyWorker
    {
        TIME_LOCK_FARM.setRewardDuration(
            _newDuration
        );
    }

    /**
     * @dev Performs a deposit for a user
     * from the owner of the contract.
     */
    function makeDepositForUser(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        external
        onlyOwner
    {
        TIME_LOCK_FARM.makeDepositForUser(
            _stakeOwner,
            _stakeAmount,
            _lockingTime,
            _initialTime
        );
    }

    /**
     * @dev Performs a deposit for a user
     * from the owner of the contract.
     */
    function makeDepositForUserFinalDate(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _finalDate,
        uint256 _initialTime
    )
        external
        onlyOwner
    {
        uint256 lockingTime = _finalDate
            - block.timestamp;

        TIME_LOCK_FARM.makeDepositForUser(
            _stakeOwner,
            _stakeAmount,
            lockingTime,
            _initialTime
        );
    }

    /**
     * @dev Allows to recover ANY tokens
     * from the private farm contract.
     * God mode feature for admin multisig.
     */
    function recoverTokens(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
        onlyOwner
    {
        safeTransfer(
            tokenAddress,
            msg.sender,
            tokenAmount
        );
    }
}
