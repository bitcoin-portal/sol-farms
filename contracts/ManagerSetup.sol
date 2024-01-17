// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.23;

import "./SafeERC20.sol";
import "./ITimeLockFarmV2Dual.sol";

import "./ManagerHelper.sol";

contract ManagerSetup is ManagerHelper, SafeERC20 {

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

        _setupAmounts();
        _setupAllocations();

        require(
            allocations.length == EXPECTED_ALLOCATIONS,
            "ManagerSetup: ALLOCATIONS_COUNT_MISMATCH"
        );

        require(
            initialTokensRequired == EXPECTED_TOTAL_TOKENS,
            "ManagerSetup: EXPECTED_TOKENS_MISMATCH"
        );

        for (uint256 i; i < uniqueAmounts.length; i++) {
            require(
                expectedUniqueAmounts[uniqueAmounts[i].amount] == 0,
                "ManagerSetup: UNIQUE_AMOUNT_MISMATCH"
            );
        }
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
     * @dev Performs a deposit for all users
     * from the allocations array. This function
     * can be called only once by worker once
     * the contract is deployed and funded.
     */
    function executeAllocations()
        external
        onlyWorker
    {
        require(
            isInitialized == false,
            "ManagerSetup: ALREADY_INITIALIZED"
        );

        isInitialized = true;

        uint256 i;
        uint256 l = allocations.length;

        while (i < l) {

            _preventDuplicate(
                allocations[i].stakeOwner
            );

            bool res = _executeAllocation(
                allocations[i]
            );

            require(
                res == allocations[i].unlock20Percent,
                "ManagerSetup: ALLOCATION_MALFORMED"
            );

            unchecked {
                ++i;
            }
        }
    }

    function _executeAllocation(
        Allocation memory allocation
    )
        internal
        returns (bool)
    {
        if (allocation.unlock20Percent == true) {

            TIME_LOCK_FARM.makeDepositForUser({
                _stakeOwner: allocation.stakeOwner,
                _stakeAmount: get20Percent(allocation.stakeAmount),
                _lockingTime: 0,
                _initialTime: block.timestamp
            });

            TIME_LOCK_FARM.makeDepositForUser({
                _stakeOwner: allocation.stakeOwner,
                _stakeAmount: get80Percent(allocation.stakeAmount),
                _lockingTime: allocation.lockingTime,
                _initialTime: allocation.initialTime
            });

            return true;
        }

        TIME_LOCK_FARM.makeDepositForUser({
            _stakeOwner: allocation.stakeOwner,
            _stakeAmount: allocation.stakeAmount,
            _lockingTime: allocation.lockingTime,
            _initialTime: allocation.initialTime
        });

        return false;
    }

    function _preventDuplicate(
        address _stakeOwner
    )
        internal
    {
        require(
            isAllocationExecuted[_stakeOwner] == false,
            "ManagerSetup: DUPLICATE_ALLOCATION"
        );

        isAllocationExecuted[_stakeOwner] = true;
    }

    function get20Percent(
        uint256 _amount
    )
        public
        pure
        returns (uint256)
    {
        return _amount * 20E16;
    }

    function get80Percent(
        uint256 _amount
    )
        public
        pure
        returns (uint256)
    {
        return _amount * 80E16;
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
