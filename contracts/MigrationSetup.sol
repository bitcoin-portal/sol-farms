// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./SafeERC20.sol";
import "./ManagerHelper.sol";
import "./TimeLockFarmV2Dual.sol";

contract MigrationSetup is ManagerHelper, SafeERC20 {

    IERC20 public immutable VERSE;
    IERC20 public immutable STABLECOIN;

    address public owner;
    address public worker;

    bool public isMigrated;

    TimeLockFarmV2Dual public immutable OLD_FARM;
    TimeLockFarmV2Dual public immutable NEW_FARM;

    uint256 public constant FINAL_DATE = 1798675200;
    uint256 public constant DEFAULT_DURATION = 30 days;

    uint256 public latestRewardsSnapshotBlock;

    mapping(address => bool) public isAllocationExecuted;
    mapping(address => uint256) public rewardsOldFarmA;
    mapping(address => uint256) public rewardsOldFarmB;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "MigrationSetup: NOT_OWNER"
        );
        _;
    }

    modifier onlyWorker() {
        require(
            msg.sender == worker,
            "MigrationSetup: NOT_WORKER"
        );
        _;
    }

    constructor(
        address _owner,
        address _worker,
        address _oldFarm,
        address _newFarm
    ) {
        OLD_FARM = TimeLockFarmV2Dual(
            _oldFarm
        );

        owner = _owner;
        worker = _worker;

        VERSE = IERC20(
            0xc708D6F2153933DAA50B2D0758955Be0A93A8FEc
        );

        STABLECOIN = IERC20(
            0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
        );

        NEW_FARM = TimeLockFarmV2Dual(
            _newFarm
        );

        _setupAmounts();
        _setupAllocations();

        require(
            allocations.length == EXPECTED_ALLOCATIONS,
            "MigrationSetup: ALLOCATIONS_COUNT_MISMATCH"
        );

        require(
            initialTokensRequired == EXPECTED_TOTAL_TOKENS,
            "MigrationSetup: EXPECTED_TOKENS_MISMATCH"
        );

        for (uint256 i; i < uniqueAmounts.length; i++) {
            require(
                expectedUniqueAmounts[uniqueAmounts[i].amount] == 0,
                "MigrationSetup: UNIQUE_AMOUNT_MISMATCH"
            );
        }
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
        TimeLockFarmV2Dual(_farm).claimOwnership();
    }

    function proposeNewOwnerAnyFarm(
        address _farm,
        address _newOwner
    )
        external
        onlyOwner
    {
        TimeLockFarmV2Dual(
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
        TimeLockFarmV2Dual(
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
        address _farm,
        uint256 _newRateA,
        uint256 _newRateB
    )
        external
        onlyWorker
    {
        TimeLockFarmV2Dual(
            _farm
        ).setRewardRates(
            _newRateA,
            _newRateB
        );
    }

    /**
     * @dev Sets the reward duration for the
     * private farm contract only by worker
     */
    function setRewardDuration(
        address _farm,
        uint256 _newDuration
    )
        external
        onlyWorker
    {
        TimeLockFarmV2Dual(
            _farm
        ).setRewardDuration(
            _newDuration
        );
    }

    /**
     * @dev Sponsors the initial rewards for token A
     */
    function _sponsorInitialRewardA(
        address _stakeOwner,
        uint256 _initialRewardsAmountA
    )
        internal
    {
        NEW_FARM.sponsorInitialRewardA(
            _stakeOwner,
            _initialRewardsAmountA
        );
    }

    /**
     * @dev Sponsors the initial rewards for token B
     */
    function _sponsorInitialRewardB(
        address _stakeOwner,
        uint256 _initialRewardsAmountB
    )
        internal
    {
        NEW_FARM.sponsorInitialRewardB(
            _stakeOwner,
            _initialRewardsAmountB
        );
    }

    /**
     * @dev Performs a deposit for a user
     * from the owner of the contract.
     */
    function _makeDepositForUserNewFarm(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        internal
    {
        VERSE.approve(
            address(NEW_FARM),
            _stakeAmount
        );

        NEW_FARM.makeDepositForUser(
            _stakeOwner,
            _stakeAmount,
            _lockingTime,
            _initialTime
        );
    }

    function adjustRewardSnapshotValues(
        address _stakeOwner,
        uint256 _rewardTokenA,
        uint256 _rewardTokenB
    )
        external
        onlyOwner
    {
        rewardsOldFarmA[_stakeOwner] = _rewardTokenA;
        rewardsOldFarmB[_stakeOwner] = _rewardTokenB;
    }

    function makeRewardsSnapshot()
        external
        onlyOwner
    {
        uint256 l = allocations.length;
        address stakeOwner;
        uint256 i;

        uint256 rewardTokenA;
        uint256 rewardTokenB;

        while (i < l) {

            stakeOwner = allocations[i].stakeOwner;

            rewardTokenA = OLD_FARM.earnedA(
                stakeOwner
            );

            rewardTokenB = OLD_FARM.earnedB(
                stakeOwner
            );

            rewardsOldFarmA[stakeOwner] = rewardTokenA;
            rewardsOldFarmB[stakeOwner] = rewardTokenB;

            unchecked {
                ++i;
            }
        }

        latestRewardsSnapshotBlock = block.number;
    }

    function restoreRewardsSnapshot()
        external
        onlyOwner
    {
        uint256 l = allocations.length;
        address stakeOwner;
        uint256 i;

        uint256 rewardTokenA;
        uint256 rewardTokenB;

        while (i < l) {

            stakeOwner = allocations[i].stakeOwner;

            rewardTokenA = rewardsOldFarmA[
                stakeOwner
            ];

            rewardTokenB = rewardsOldFarmB[
                stakeOwner
            ];

            if (rewardTokenA > 0) {
                _sponsorInitialRewardA(
                    stakeOwner,
                    rewardTokenA
                );
            }

            if (rewardTokenB > 0) {
                _sponsorInitialRewardB(
                    stakeOwner,
                    rewardTokenB
                );
            }

            unchecked {
                ++i;
            }
        }
    }

    function executeSyncBalances(
        uint256 _from,
        uint256 _to
    )
        external
        onlyOwner
    {
        uint256 i = _from;
        uint256 l = _to;
        address stakeOwner;

        uint256 currentTime = block.timestamp;
        uint256 vestingTime = FINAL_DATE - currentTime;

        uint256 lockedTokens;
        uint256 assignedTokens;
        uint256 unlockedTokens;

        uint256 currentBalance;
        uint256 maxPossibleBalance;

        while (i < l) {

            stakeOwner = allocations[i].stakeOwner;

            require(
                isAllocationExecuted[stakeOwner] == false,
                "MigrationSetup: ALREADY_MIGRATED"
            );

            isAllocationExecuted[stakeOwner] = true;

            // 1. Get the remaining tokens assigned
            assignedTokens = OLD_FARM.balanceOf(
                stakeOwner
            );

            // 2. Get the unlocked portion of assigned tokens
            unlockedTokens = OLD_FARM.unlockable(
                stakeOwner
            );

            // 3. Calculate the locked tokens
            lockedTokens = assignedTokens
                - unlockedTokens;

            // 4. Make the deposit for the new farm (locked part)
            _makeDepositForUserNewFarm({
                _stakeOwner: stakeOwner,
                _stakeAmount: lockedTokens,
                _lockingTime: vestingTime, // <-- correct vesting end-time
                _initialTime: currentTime
            });

            currentBalance = NEW_FARM.balanceOf(
                stakeOwner
            );

            maxPossibleBalance = expectedInitialAmount[
                stakeOwner
            ] * 1E18;

            unlockedTokens = currentBalance + unlockedTokens > maxPossibleBalance
                ? maxPossibleBalance - currentBalance
                : unlockedTokens;

            // 5. Make the deposit for the new farm (unlocked part)
            _makeDepositForUserNewFarm({
                _stakeOwner: stakeOwner,
                _stakeAmount: unlockedTokens,
                _lockingTime: 0,
                _initialTime: currentTime
            });

            unchecked {
                ++i;
            }
        }
    }

    function getAllocationStakeOwner(
        uint256 _index
    )
        public
        view
        returns (address)
    {
        return allocations[_index].stakeOwner;
    }

    function getAllocation(
        uint256 _index
    )
        external
        view
        returns (
            address stakeOwner,
            uint256 stakeAmount,
            uint256 lockingTime,
            uint256 initialTime,
            bool unlock20Percent
        )
    {
        Allocation memory allocation = allocations[
            _index
        ];

        stakeOwner = allocation.stakeOwner;
        stakeAmount = allocation.stakeAmount;
        lockingTime = allocation.lockingTime;
        initialTime = allocation.initialTime;
        unlock20Percent = allocation.unlock20Percent;
    }

    /**
     * @dev Allows to recover ANY tokens
     * from migration contract.
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

    /**
     * @dev Allows to recover ANY tokens
     * from new farm contract.
     * God mode feature for admin multisig.
     */
    function recoverTokensFromAnyFarm(
        address _farm,
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
        onlyOwner
    {
        TimeLockFarmV2Dual(_farm).recoverTokens(
            tokenAddress,
            tokenAmount
        );
    }
}
