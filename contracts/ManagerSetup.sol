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

    mapping (address => bool) public isAllocationExecuted;

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

        _setupAllocations();

        require(
            allocations.length == EXPECTED_ALLOCATIONS,
            "ManagerSetup: ALLOCATIONS_COUNT_MISMATCH"
        );

        /*
        // Uncomment this code to check the total amount of tokens
        uint256 i;
        uint256 l = allocations.length;
        uint256 totalTokens;

        while (i < l) {
            totalTokens += allocations[i].stakeAmount;
            unchecked {
                ++i;
            }
        }

        require(
            totalTokens == EXPECTED_TOTAL_TOKENS,
            "ManagerSetup: TOTAL_TOKENS_MISMATCH"
        );
        */
    }

    function setWorker(
        address _newWorker
    )
        external
        onlyOwner
    {
        worker = _newWorker;
    }

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
        IERC20(tokenAddress).transfer(
            owner,
            tokenAmount
        );
    }

    function executeAllocations()
        external
        onlyOwner
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
                _lockingTime: 0
            });

            TIME_LOCK_FARM.makeDepositForUser({
                _stakeOwner: allocation.stakeOwner,
                _stakeAmount: get80Percent(allocation.stakeAmount),
                _lockingTime: allocation.vestingTime
            });

            return true;
        }

        TIME_LOCK_FARM.makeDepositForUser({
            _stakeOwner: allocation.stakeOwner,
            _stakeAmount: allocation.stakeAmount,
            _lockingTime: allocation.vestingTime
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
}