// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "./SafeERC20.sol";
import "./ManagerSetup.sol";
import "./ManagerHelper.sol";
import "./TimeLockFarmV2Dual.sol";

contract RescueSetup is ManagerHelper, SafeERC20 {

    IERC20 public immutable VERSE;
    IERC20 public immutable STABLECOIN;

    address public owner;
    address public worker;

    bool public isMigrated;

    ManagerSetup public MANAGER_SETUP;
    TimeLockFarmV2Dual public TIME_LOCK_FARM;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "MigrationSetup: NOT_OWNER"
        );
        _;
    }

    constructor(
        address _timeLockFarm,
        address _managerSetup
    ) {
        TIME_LOCK_FARM = TimeLockFarmV2Dual(
            _timeLockFarm
        );

        MANAGER_SETUP = ManagerSetup(
            _managerSetup
        );

        owner = msg.sender;

        VERSE = IERC20(
            TIME_LOCK_FARM.stakeToken()
        );

        STABLECOIN = IERC20(
            TIME_LOCK_FARM.rewardTokenB()
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

    /**
     * @dev Sets the owner of the contract.
     * Owner can perform only certain actions.
     */
    function changeRescueOwner(
        address _newOwner
    )
        external
        onlyOwner
    {
        owner = _newOwner;
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
        onlyOwner
    {
        MANAGER_SETUP.setRewardRates(
            _newRateA,
            _newRateB
        );
    }

    function enterDaiSavingMode(
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _rewardDuration,
        uint256 _rewardRateB
    )
        external
        onlyOwner
    {
        _createStake({
            _stakeOwner: 0x22079A848266A7D2E40CF0fF71a6573D78adcF37,
            _stakeAmount: _stakeAmount,
            _lockingTime: _lockingTime,
            _initialTime: block.timestamp
        });

        _createStake({
            _stakeOwner: 0xa803c226c8281550454523191375695928DcFE92,
            _stakeAmount: _stakeAmount,
            _lockingTime: _lockingTime,
            _initialTime: block.timestamp
        });

        _createStake({
            _stakeOwner: 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
            _stakeAmount: _stakeAmount,
            _lockingTime: _lockingTime,
            _initialTime: block.timestamp
        });

        _setRewardDuration({
            _rewardDuration: _rewardDuration
        });

        _setRewardRates({
            _rewardRateA: 1,
            _rewardRateB: _rewardRateB
        });
    }

    function enterRescueMode(
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _rewardDuration,
        uint256 _rewardRateA
    )
        external
        onlyOwner
    {
        _createStake({
            _stakeOwner: address(this),
            _stakeAmount: _stakeAmount,
            _lockingTime: _lockingTime,
            _initialTime: block.timestamp
        });

        _setRewardDuration({
            _rewardDuration: _rewardDuration
        });

        _setRewardRates({
            _rewardRateA: _rewardRateA,
            _rewardRateB: 1
        });
    }

    function triggerFarmUpdate()
        external
        onlyOwner
    {
        _createStake({
            _stakeOwner: address(0x0),
            _stakeAmount: 0,
            _lockingTime: 0 minutes,
            _initialTime: block.timestamp
        });
    }

    function createStake(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        external
        onlyOwner
    {
        _createStake(
            _stakeOwner,
            _stakeAmount,
            _lockingTime,
            _initialTime
        );
    }

    function _createStake(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        private
    {
        MANAGER_SETUP.makeDepositForUser(
            _stakeOwner,
            _stakeAmount,
            _lockingTime,
            _initialTime
        );
    }

    function claimReward()
        external
        onlyOwner
    {
        TIME_LOCK_FARM.claimReward();
    }

    function farmWithdraw(
        uint256 _withdrawAmount
    )
        external
        onlyOwner
    {
        TIME_LOCK_FARM.farmWithdraw(
            _withdrawAmount
        );
    }

    function exitFarm()
        external
        onlyOwner
    {
        TIME_LOCK_FARM.exitFarm();
    }

    function exitFarmPrepareRepeat()
        external
        onlyOwner
    {
        TIME_LOCK_FARM.exitFarm();

        VERSE.transfer(
            address(MANAGER_SETUP),
            VERSE.balanceOf(address(this))
        );
    }

    /**
     * @dev Allows to recover ANY tokens
     * from rescue contract.
     * God mode feature for admin multisig.
     */
    function recoverTokensFromSelf(
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
     * from manager contract.
     * God mode feature for admin multisig.
     */
    function recoverTokensFromManager(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
        onlyOwner
    {
        MANAGER_SETUP.recoverTokens(
            tokenAddress,
            tokenAmount
        );
    }

    function setOwnerOnManagerContract(
        address _newOwner
    )
        external
        onlyOwner
    {
        MANAGER_SETUP.setOwner(
            _newOwner
        );
    }

    function setOwnerOnManagerSetup(
        address _farmContract,
        address _newOwner
    )
        external
        onlyOwner
    {
        ManagerSetup(_farmContract).setOwner(
            _newOwner
        );
    }

    function setWorkerOnManagerContract(
        address _newWorker
    )
        external
        onlyOwner
    {
        MANAGER_SETUP.setWorker(
            _newWorker
        );
    }

    function setDurationThroughManager(
        uint256 _newDuration
    )
        external
        onlyOwner
    {
        _setRewardDuration({
            _rewardDuration: _newDuration
        });
    }

    function _setRewardDuration(
        uint256 _rewardDuration
    )
        private
    {
        MANAGER_SETUP.setRewardDuration(
            _rewardDuration
        );
    }

    function setRewardsThroughManager(
        uint256 _newRateA,
        uint256 _newRateB
    )
        external
        onlyOwner
    {
        _setRewardRates(
            _newRateA,
            _newRateB
        );
    }

    function _setRewardRates(
        uint256 _rewardRateA,
        uint256 _rewardRateB
    )
        private
    {
        MANAGER_SETUP.setRewardRates(
            _rewardRateA,
            _rewardRateB
        );
    }

    function changeTargets(
        address _managerSetup,
        address _farmContract
    )
        external
        onlyOwner
    {
        MANAGER_SETUP = ManagerSetup(
            _managerSetup
        );

        TIME_LOCK_FARM = TimeLockFarmV2Dual(
            _farmContract
        );
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
}
