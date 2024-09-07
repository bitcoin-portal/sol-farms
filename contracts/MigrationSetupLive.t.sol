// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.25;

import "forge-std/Test.sol";

import "./MigrationSetup.sol";
import "./TimeLockFarmV2Dual.sol";

contract MigrationSetupLive is Test {

    TimeLockFarmV2Dual public farm = TimeLockFarmV2Dual(
        0x775573fC6A3E9E1f9a12E21B504073c0D66F4ef4
    );

    MigrationSetup public migration = MigrationSetup(
        0x702a2CE346d34d7719f48A4D6d0b4F6846E6198e
    );

    TimeLockFarmV2Dual public newFarm = TimeLockFarmV2Dual(
        0xc0fE1b6077C986C60CE14D09f29193e52b006cbA
    );

    IERC20 public verseToken;
    IERC20 public stableToken;

    uint256 constant FORK_MAINNET_BLOCK = 53_543_310;

    address constant ADMIN_ADDRESS = address(
        0x9492aF5Cb2b54108bD99707FF3c9146A3Eb5E82e
    );

    address constant HOLDER_ADDRESS = address(
        0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689
    );

    address constant USER_ADDRESS = address(
        0x127564F78d371ECcE6Ab86A179Be4e4378B6ea3D
    );

    address constant FUTURE_ADDRES = address(
        0x216b6F99CA2bf53d801fE9Ba7d68fADC4949249B
    );

    address constant ZERO_ADDRESS = address(0x0);
    uint256 public constant DEFAULT_DURATION = 30 days;

    bool public constant LOGS_ENABLE = false;

    function _log(
        uint256 _a,
        address _b
    )
        internal
        view
    {
        if (LOGS_ENABLE == true) {
            console.log(
                _a,
                _b
            );
        }
    }

    function _log(
        uint256 _amount,
        string memory _message
    )
        internal
        view
    {
        if (LOGS_ENABLE == true) {
            console.log(
                _amount,
                _message
            );
        }
    }

    function _log(
        address _addy,
        string memory _message
    )
        internal
        view
    {
        if (LOGS_ENABLE == true) {
            console.log(
                _addy,
                _message
            );
        }
    }

    function tokens(
        uint256 _amount
    )
        internal
        pure
        returns (uint256)
    {
        return _amount * 10 ** 18;
    }

    function setUp()
        public
    {
        vm.createSelectFork(
            vm.rpcUrl("polygon"),
            FORK_MAINNET_BLOCK
        );

        verseToken = IERC20(
            farm.rewardTokenA()
        );

        stableToken = IERC20(
            farm.rewardTokenB()
        );


        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        vm.stopPrank();
    }

    function testProposeNewOwner()
        public
    {
        vm.startPrank(
            migration.owner()
        );

        address currentOwner = newFarm.ownerAddress();

        // _log(currentOwner, 'currentOwner');
        // _log(address(migration), 'migration contract');
        // _log(address(newFarm), 'newFarm');
        // _log(address(migration.MIGRATED_NEW_FARM()), 'newFarm in migration contract');

        assertEq(
            currentOwner,
            address(migration),
            "Owner should be the same"
        );

        address candidate = newFarm.proposedOwner();

        assertEq(
            candidate,
            ADMIN_ADDRESS,
            "Candidate should be the same"
        );

        vm.stopPrank();
        vm.startPrank(ADMIN_ADDRESS);

        newFarm.claimOwnership();

        address newOwner = newFarm.ownerAddress();

        assertEq(
            newOwner,
            ADMIN_ADDRESS,
            "New owner should be changed"
        );

        vm.stopPrank();
    }

    /**
     * @dev --> notice
     * Rewards are also checked to ensure that they
     * are not lost during the migration process.
     */
    function testMigrationCheckRewardA()
        public
    {
        address migrationFarmOwner = migration.owner();

        // address migrationFarmWorker = migration.worker();
        // console.log(migrationFarmOwner, 'migrationFarmOwner');
        // console.log(migrationFarmWorker, 'migrationFarmWorker');

        vm.startPrank(
            migrationFarmOwner
        );

        vm.warp(
            1708000000
        );

        uint256 userRewardOldFarmA = farm.earnedA(
            USER_ADDRESS
        );

        uint256 userRewardBeforeNewFarmA = newFarm.earnedA(
            USER_ADDRESS
        );

        assertGt(
            userRewardOldFarmA,
            0,
            "User reward A should be above 0 in old farm"
        );

        assertEq(
            userRewardBeforeNewFarmA,
            0,
            "User reward A should be 0 in new farm"
        );

        // START EXECUTE MIGRATION
        // migration.executeSyncBalances(
            // 0,
            // 10
        // );
        // FINISH EXECUTE MIGRATION

        uint256 userRewardAfterOldFarmA = farm.earnedA(
            USER_ADDRESS
        );

        assertEq(
            userRewardAfterOldFarmA,
            0,
            "User reward A should be 0 in old farm (after migration)"
        );

        uint256 userRewardNewFarmA = newFarm.earnedA(
            USER_ADDRESS
        );

        assertEq(
            userRewardNewFarmA,
            userRewardOldFarmA,
            "User reward A should be the same between farms (after migration)"
        );
    }

    /**
     * @dev --> notice
     * Rewards are also checked to ensure that they
     * are not lost during the migration process.
     */
    function testMigrationCheckRewardB()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        vm.warp(
            1708000000
        );

        uint256 userRewardOldFarmB = farm.earnedB(
            USER_ADDRESS
        );

        assertGt(
            userRewardOldFarmB,
            0,
            "User reward B should be above 0 in old farm"
        );

        uint256 userRewardBeforeNewFarmB = newFarm.earnedB(
            USER_ADDRESS
        );

        assertEq(
            userRewardBeforeNewFarmB,
            0,
            "User reward B should be 0 in new farm"
        );

        // START EXECUTE MIGRATION
        // FINISH EXECUTE MIGRATION

        uint256 userRewardAfterOldFarmB = farm.earnedB(
            USER_ADDRESS
        );

        assertEq(
            userRewardAfterOldFarmB,
            0,
            "User reward B should be 0 in old farm (after migration)"
        );

        uint256 userRewardNewFarmB = newFarm.earnedB(
            USER_ADDRESS
        );

        assertEq(
            userRewardNewFarmB,
            userRewardOldFarmB,
            "User reward B should be the same between farms (after migration)"
        );
    }

    /**
     * @dev --> notice
     * User balance is checked to ensure that it is not lost
     * during the migration process.
     */
    function testMigrationUnlockedBalance()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        vm.warp(
            1708000000
        );

        uint256 balanceBefore = farm.balanceOf(
            USER_ADDRESS
        );

        uint256 unlockedBefore = farm.unlockable(
            USER_ADDRESS
        );

        assertGt(
            balanceBefore,
            0,
            "User balance should be above 0"
        );

        assertGt(
            unlockedBefore,
            0,
            "User unlockable should be above 0"
        );

        uint256 balanceBeforeNewFarm = newFarm.balanceOf(
            USER_ADDRESS
        );

        assertEq(
            balanceBeforeNewFarm,
            0,
            "User balance should be 0 in new farm"
        );

        uint256 migrationBalanceBefore = farm.balanceOf(
            address(migration)
        );

        assertEq(
            migrationBalanceBefore,
            0,
            "Migration balance should be 0"
        );

        uint256 migrationContractVerseBalanceBefore = verseToken.balanceOf(
            address(migration)
        );

        assertEq(
            migrationContractVerseBalanceBefore,
            0,
            "Migration contract verse balance should be 0"
        );

        uint256 verseInOldFarmBefore = verseToken.balanceOf(
            address(farm)
        );

        uint256 oldFarmTotalSupplyBefore = farm.totalSupply();

        uint256 totalStakes;
        uint256 totalBalance;
        uint256 totalUnlocked;
        uint256 totalRewardToPayA;
        uint256 totalRewardToPayB;

        uint256 expectedDiff;

        uint256 i;
        uint256 l = migration.EXPECTED_ALLOCATIONS();

        _log(l, 'allocations.length');

        for (i; i < l; i++) {

            address stakeOwner = migration.getAllocationStakeOwner(i);

            uint256 rewardA = farm.earnedA(
                stakeOwner
            );

            uint256 rewardB = farm.earnedB(
                stakeOwner
            );

            uint256 balance = farm.balanceOf(
                stakeOwner
            );

            uint256 unlocked = farm.unlockable(
                stakeOwner
            );

            uint256 count = farm.stakeCount(
                stakeOwner
            );

            if (count == 1) {
                expectedDiff++;
            }

            // console.log(stakeOwner, unlocked, balance);
            // console.log(stakeOwner, unlocked, balance);

            totalStakes += count;
            totalBalance += balance;
            totalUnlocked += unlocked;
            totalRewardToPayA += rewardA;
            totalRewardToPayB += rewardB;
        }

        // console.log('----');
        migration.executeSyncBalances(
            0,
            10
        );
        // console.log('----');

        uint256 newTotalStakes;
        uint256 newTotalBalance;
        uint256 newFarmtotalUnlocked;
        uint256 newFarmtotalRewardToPayA;
        uint256 newFarmtotalRewardToPayB;

        for (i = 0; i < l; i++) {

            address stakeOwner = migration.getAllocationStakeOwner(i);

            uint256 unlocked = newFarm.unlockable(
                stakeOwner
            );

            uint256 rewardA = newFarm.earnedA(
                stakeOwner
            );

            uint256 rewardB = newFarm.earnedB(
                stakeOwner
            );

            uint256 balance = newFarm.balanceOf(
                stakeOwner
            );

            uint256 count = newFarm.stakeCount(
                stakeOwner
            );

            // console.log(stakeOwner, count);
            // console.log(stakeOwner, unlocked, balance);

            newTotalStakes += count;
            newTotalBalance += balance;
            newFarmtotalUnlocked += unlocked;
            newFarmtotalRewardToPayA += rewardA;
            newFarmtotalRewardToPayB += rewardB;
        }

        assertEq(
            totalStakes,
            newTotalStakes - expectedDiff,
            "Total stakes should be the same"
        );

        assertEq(
            totalBalance,
            newTotalBalance,
            "Total balance should be the same"
        );

        assertEq(
            totalUnlocked,
            newFarmtotalUnlocked,
            "Total unlocked should be the same"
        );

        assertEq(
            totalRewardToPayA,
            newFarmtotalRewardToPayA,
            "Total reward A should be the same"
        );

        assertEq(
            totalRewardToPayB,
            newFarmtotalRewardToPayB,
            "Total reward B should be the same"
        );

        assertEq(
            verseInOldFarmBefore,
            verseToken.balanceOf(
                address(newFarm)
            ),
            "Verse in farm should be the same"
        );

        assertEq(
            oldFarmTotalSupplyBefore,
            newFarm.totalSupply(),
            "Farm total supply should be the same"
        );
    }

    function testExecuteMigrationNew()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        vm.warp(
            1708000000
        );

        uint256 balanceBeforeForUserInOldFarm = farm.balanceOf(
            USER_ADDRESS
        );

        uint256 balanceBeforeForUserInNewFarm = newFarm.balanceOf(
            USER_ADDRESS
        );

        assertEq(
            balanceBeforeForUserInNewFarm,
            0,
            "User balance should be 0 in new farm"
        );

        uint256 migrationBalanceBefore = farm.balanceOf(
            address(migration)
        );

        assertEq(
            migrationBalanceBefore,
            0,
            "Migration balance should be 0"
        );

        uint256 migrationContractVerseBalanceBefore = verseToken.balanceOf(
            address(migration)
        );

        assertEq(
            migrationContractVerseBalanceBefore,
            0,
            "Migration contract verse balance should be 0"
        );

        assertGt(
            balanceBeforeForUserInOldFarm,
            0,
            "User balance should be above 0"
        );

        assertEq(
            balanceBeforeForUserInNewFarm,
            0,
            "User balance should be 0"
        );

        uint256 verseInOldFarmBefore = verseToken.balanceOf(
            address(farm)
        );

        uint256 oldFarmTotalSupplyBefore = farm.totalSupply();


        // uint256 totalUnlocked;
        uint256 totalRewardToPayA;
        uint256 totalRewardToPayB;

        uint256 i;
        uint256 l = migration.EXPECTED_ALLOCATIONS();

        _log(l, 'allocations.length');

        for (i; i < l; i++) {

            uint256 rewardA = farm.earnedA(
                migration.getAllocationStakeOwner(i)
            );

            uint256 rewardB = farm.earnedB(
                migration.getAllocationStakeOwner(i)
            );

            /*
            uint256 balance = farm.balanceOf(
                migration.getAllocationStakeOwner(i)
            );
            uint256 unlocked = farm.unlockable(
                migration.getAllocationStakeOwner(i)
            );
            uint256 count = farm.stakeCount(
                migration.getAllocationStakeOwner(i)
            );
            */

            // totalUnlocked += unlocked;
            totalRewardToPayA += rewardA;
            totalRewardToPayB += rewardB;

            // _log(count, 'countBefore');
            // _log(balance, 'balanceBefore');
            // _log(unlocked, 'unlockedBefore');
        }

        _log(totalRewardToPayA, 'totalRewardToPayA');
        _log(totalRewardToPayB, 'totalRewardToPayB');


        // MAIN THING -----
        migration.executeSyncBalances(
            0,
            10
        );
        // MAIN THING ----

        uint256 oldFarmTotalSupplyAfter = farm.totalSupply();
        uint256 newFarmTotalSupplyAfter = newFarm.totalSupply();

        assertEq(
            oldFarmTotalSupplyAfter,
            oldFarmTotalSupplyBefore,
            "Farm total supply should be the same (old vs old)"
        );

        assertEq(
            newFarmTotalSupplyAfter,
            oldFarmTotalSupplyBefore,
            "Farm total supply should be the same (new vs old)"
        );

        _log(oldFarmTotalSupplyBefore, 'oldFarmTotalSupplyBefore');
        _log(oldFarmTotalSupplyAfter, 'oldFarmTotalSupplyAfter');
        _log(newFarmTotalSupplyAfter, 'newFarmTotalSupplyAfter');

        /*
        for (i = 0; i < l; i++) {
            uint256 balance = farm.balanceOf(
                migration.getAllocationStakeOwner(i)
            );
            uint256 unlocked = farm.unlockable(
                migration.getAllocationStakeOwner(i)
            );
            uint256 count = farm.stakeCount(
                migration.getAllocationStakeOwner(i)
            );
            _log(balance, 'balanceAfter');
            _log(unlocked, 'unlockedAfter');
            _log(count, 'countAfter');
        }*/

        uint256 verseInNewFarmAfter = verseToken.balanceOf(
            address(newFarm)
        );

        assertEq(
            verseInNewFarmAfter,
            verseInOldFarmBefore,
            "Verse in farm should be the same old -> new"
        );

        uint256 balanceAfterForUserInNewFarm = newFarm.balanceOf(
            USER_ADDRESS
        );

        assertEq(
            balanceAfterForUserInNewFarm,
            balanceBeforeForUserInOldFarm,
            "User balance should be the same"
        );

        /*
        assertEq(
            balanceAfter,
            0
        );
        */
        // _log(verseBalanceAfter, 'verseBalanceAfter');
        // _log(migrationBalanceAfter, 'migrationBalanceAfter');

        vm.stopPrank();
    }

    function testExecuteMigration()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        uint256 balanceBefore = farm.balanceOf(
            USER_ADDRESS
        );

        uint256 migrationBalanceBefore = farm.balanceOf(
            address(migration)
        );

        uint256 verseBalanceBefore = verseToken.balanceOf(
            address(migration)
        );

        assertEq(
            verseBalanceBefore,
            0,
            "Verse balance should be 0"
        );

        assertEq(
            migrationBalanceBefore,
            0,
            "Migration balance should be 0"
        );

        assertGt(
            balanceBefore,
            0,
            "User balance should be above 0"
        );

        uint256 verseInFarmBefore = verseToken.balanceOf(
            address(farm)
        );

        uint256 farmTotalSupplyBefore = farm.totalSupply();

        _log(verseInFarmBefore, 'userverseInFarmBefore');
        _log(balanceBefore, 'userBalanceBefore');
        _log(verseBalanceBefore, 'verseBalanceBefore');

        // uint256 totalUnlocked;
        uint256 totalRewardToPayA;
        // uint256 totalRewardToPayB;

        uint256 i;
        uint256 l = migration.EXPECTED_ALLOCATIONS();

        _log(l, 'allocations.length');
        _log(farmTotalSupplyBefore, 'farmTotalSupplyBefore');

        for (i; i < l; i++) {

            uint256 rewardA = farm.earnedA(
                migration.getAllocationStakeOwner(i)
            );

            /*
            uint256 rewardB = farm.earnedB(
                migration.getAllocationStakeOwner(i)
            );

            uint256 balance = farm.balanceOf(
                migration.getAllocationStakeOwner(i)
            );
            uint256 unlocked = farm.unlockable(
                migration.getAllocationStakeOwner(i)
            );
            uint256 count = farm.stakeCount(
                migration.getAllocationStakeOwner(i)
            );
            */

            // totalUnlocked += unlocked;
            totalRewardToPayA += rewardA;
            // totalRewardToPayB += rewardB;

            // _log(count, 'countBefore');
            // _log(balance, 'balanceBefore');
            // _log(unlocked, 'unlockedBefore');
        }

        _log(totalRewardToPayA, 'totalRewardToPayA');
        // _log(totalRewardToPayB, 'totalRewardToPayB');

        // MAIN THING -----
        migration.executeSyncBalances(
            0,
            10
        );
        // MAIN THING ----

        uint256 farmTotalSupplyAfter = farm.totalSupply();

        _log(farmTotalSupplyAfter, 'farmTotalSupplyAfter');

        assertEq(
            farmTotalSupplyAfter,
            farmTotalSupplyBefore,
            "Farm total supply should be the same"
        );

        /*
        for (i = 0; i < l; i++) {
            uint256 balance = farm.balanceOf(
                migration.getAllocationStakeOwner(i)
            );
            uint256 unlocked = farm.unlockable(
                migration.getAllocationStakeOwner(i)
            );
            uint256 count = farm.stakeCount(
                migration.getAllocationStakeOwner(i)
            );

            _log(balance, 'balanceAfter');
            _log(unlocked, 'unlockedAfter');
            _log(count, 'countAfter');
        }*/

        uint256 verseInFarmAfter = verseToken.balanceOf(
            address(farm)
        );

        _log(verseInFarmAfter, 'verseInFarmAfter');

        uint256 balanceAfter = farm.balanceOf(
            USER_ADDRESS
        );

        uint256 migrationBalanceAfter = verseToken.balanceOf(
            address(migration)
        );

        uint256 farmTokensForMigration = farm.balanceOf(
            address(migration)
        );

        uint256 verseBalanceAfter = verseToken.balanceOf(
            address(newFarm)
        );

        /*
        assertEq(
            balanceAfter,
            0
        );
        */

        assertEq(
            farmTokensForMigration,
            farmTotalSupplyBefore,
            "Farm tokens for migration should be the same as total supply of old farm"
        );

        assertEq(
            verseInFarmAfter,
            0,
            "Verse in farm after should be 0"
        );

        assertEq(
            migrationBalanceAfter,
            0,
            "Migration balance should be 0"
        );

        assertEq(
            verseBalanceAfter,
            verseInFarmBefore,
            "User balance should be the same"
        );

        _log(balanceAfter, 'userBalanceAfter');
        _log(verseBalanceAfter, 'verseBalanceAfter');
        _log(migrationBalanceAfter, 'migrationBalanceAfter');

        vm.stopPrank();
    }

    function testMigrationUserBalance()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        uint256 balanceBefore = farm.balanceOf(
            USER_ADDRESS
        );

        migration.executeSyncBalances(
            0,
            10
        );

        uint256 balanceAfterOldFarm = farm.balanceOf(
            USER_ADDRESS
        );

        uint256 balanceAfterNewFarm = newFarm.balanceOf(
            USER_ADDRESS
        );

        assertEq(
            balanceAfterNewFarm,
            balanceBefore,
            "User balance should be the same"
        );

        assertEq(
            balanceAfterOldFarm,
            0,
            "User balance should be 0 in old farm"
        );
    }

    function testMigrationRewardAfterMigration()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        uint256 rewardAOldFarm = farm.earnedA(
            USER_ADDRESS
        );

        uint256 rewardBOldFarm = farm.earnedB(
            USER_ADDRESS
        );

        migration.executeSyncBalances(
            0,
            10
        );

        uint256 rewardANewFarm = newFarm.earnedA(
            USER_ADDRESS
        );

        assertEq(
            rewardAOldFarm,
            rewardANewFarm,
            "User reward A should be the same"
        );

        uint256 rewardBNewFarm = newFarm.earnedB(
            USER_ADDRESS
        );

        assertEq(
            rewardBOldFarm,
            rewardBNewFarm,
            "User reward B should be the same"
        );

        vm.stopPrank();

        vm.startPrank(
            HOLDER_ADDRESS
        );

        verseToken.approve(
            address(newFarm),
            tokens(10_000)
        );

        stableToken.approve(
            address(newFarm),
            tokens(10_000)
        );

        newFarm.setRewardDuration(
            30 days
        );

        uint256 userRewardsBeforeRates = newFarm.earnedA(
            USER_ADDRESS
        );

        assertGt(
            userRewardsBeforeRates,
            0,
            "User rewards should be above 0"
        );

        newFarm.setRewardRates(
            10000,
            10000
        );

        vm.warp(
            block.timestamp + 15 days
        );

        uint256 userRewardsAfterRates = newFarm.earnedA(
            USER_ADDRESS
        );

        _log(userRewardsBeforeRates, 'beofre');
        _log(userRewardsAfterRates, 'after');

        _log(userRewardsAfterRates - userRewardsBeforeRates, 'diff');

        assertGt(
            userRewardsAfterRates,
            userRewardsBeforeRates,
            "User rewards should increase"
        );

        vm.stopPrank();
    }

    function testMigrationRewardAfterMigrationScrape()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        uint256 rewardAOldFarm = farm.earnedA(
            USER_ADDRESS
        );

        uint256 rewardBOldFarm = farm.earnedB(
            USER_ADDRESS
        );

        migration.executeSyncBalances(
            0,
            10
        );

        uint256 rewardANewFarm = newFarm.earnedA(
            USER_ADDRESS
        );

        assertEq(
            rewardAOldFarm,
            rewardANewFarm,
            "User reward A should be the same"
        );

        uint256 rewardBNewFarm = newFarm.earnedB(
            USER_ADDRESS
        );

        assertEq(
            rewardBOldFarm,
            rewardBNewFarm,
            "User reward B should be the same"
        );

        vm.stopPrank();

        vm.startPrank(
            USER_ADDRESS
        );

        newFarm.claimReward();

        vm.stopPrank();

        vm.startPrank(
            HOLDER_ADDRESS
        );

        verseToken.approve(
            address(newFarm),
            tokens(10_000)
        );

        stableToken.approve(
            address(newFarm),
            tokens(10_000)
        );

        newFarm.setRewardDuration(
            30 days
        );

        uint256 userRewardsBeforeRates = newFarm.earnedA(
            USER_ADDRESS
        );

        assertEq(
            userRewardsBeforeRates,
            0,
            "User rewards should be 0"
        );

        newFarm.setRewardRates(
            10000,
            10000
        );

        vm.warp(
            block.timestamp + 15 days
        );

        uint256 userRewardsAfterRates = newFarm.earnedA(
            USER_ADDRESS
        );

        _log(userRewardsBeforeRates, 'beofre');
        _log(userRewardsAfterRates, 'after');

        assertGt(
            userRewardsAfterRates,
            userRewardsBeforeRates,
            "User rewards should increase"
        );

        vm.stopPrank();
    }

    function testMigrationFinalDate()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        migration.executeSyncBalances(
            0,
            10
        );

        uint256 finalDate = migration.FINAL_DATE();

        uint256 i;
        uint256 l = migration.EXPECTED_ALLOCATIONS();

        for (i; i < l; i++) {
            (
                ,
                ,
                uint256 unlockTime
            ) = newFarm.stakes(
                migration.getAllocationStakeOwner(i),
                1
            );

            // console.log(unlockTime, 'unlockTime');

            assertEq(
                unlockTime,
                finalDate,
                "Unlock time should be the same"
            );
        }
    }

    function testMigrationRewardsFullyPaid()
        public
    {
        address migrationFarmOwner = migration.owner();

        vm.startPrank(
            migrationFarmOwner
        );

        migration.executeSyncBalances(
            0,
            10
        );


        vm.stopPrank();

        uint256 stablesInNewFarm = stableToken.balanceOf(
            address(newFarm)
        );

        // console.log(stablesInNewFarm, 'stablesInNewFarm');

        uint256 i;
        uint256 l = migration.EXPECTED_ALLOCATIONS();

        // _log(l, 'allocations.length');

        for (i; i < l; i++) {

            address stakeOwner = migration.getAllocationStakeOwner(i);

            vm.startPrank(
                stakeOwner
            );

            uint256 rewardA = newFarm.earnedA(
                stakeOwner
            );

            uint256 rewardB = newFarm.earnedB(
                stakeOwner
            );

            // console.log(stakeOwner, rewardB);

            uint256 unlockable = newFarm.unlockable(
                stakeOwner
            );

            uint256 userVerseBalanceBefore = verseToken.balanceOf(
                stakeOwner
            );

            uint256 userStableBalanceBefore = stableToken.balanceOf(
                stakeOwner
            );

            uint256 remainingBalanceVerse = verseToken.balanceOf(
                address(newFarm)
            );

            uint256 remainingBalanceStable = stableToken.balanceOf(
                address(newFarm)
            );

            newFarm.exitFarm();

            uint256 userVerseBalanceAfter = verseToken.balanceOf(
                stakeOwner
            );

            uint256 userStableBalanceAfter = stableToken.balanceOf(
                stakeOwner
            );

            uint256 remainingBalanceVerseAfter = verseToken.balanceOf(
                address(newFarm)
            );

            uint256 remainingBalanceStableAfter = stableToken.balanceOf(
                address(newFarm)
            );

            assertEq(
                remainingBalanceStable - rewardB,
                remainingBalanceStableAfter,
                "Correct amount of stable tokens"
            );

            assertGt(
                userVerseBalanceAfter,
                userVerseBalanceBefore,
                "User verse balance should be above 0"
            );

            assertGt(
                userStableBalanceAfter,
                userStableBalanceBefore,
                "User stable balance should be above 0"
            );

            assertEq(
                userVerseBalanceAfter,
                userVerseBalanceBefore + unlockable + rewardA
            );

            assertEq(
                userStableBalanceAfter,
                userStableBalanceBefore + rewardB
            );

            assertEq(
                remainingBalanceVerse,
                rewardA + unlockable + remainingBalanceVerseAfter,
                "Old balance should be new balnace + reward + unlcoked"
            );

            vm.stopPrank();
        }

        uint256 stablesInNewFarmAfter = stableToken.balanceOf(
            address(newFarm)
        );

        assertGt(
            stablesInNewFarm,
            stablesInNewFarmAfter,
            "Stable tokens should reduce"
        );

        vm.startPrank(
            HOLDER_ADDRESS
        );

        verseToken.transfer(
            address(migration),
            tokens(10_000)
        );

        stableToken.transfer(
            address(migration),
            tokens(10_000)
        );

        vm.stopPrank();

        vm.startPrank(
            migrationFarmOwner
        );

        migration.setWorker(
            migrationFarmOwner
        );

        uint256 stableBalanceInNewFarmBeforeTopUp = stableToken.balanceOf(
            address(newFarm)
        );

        assertEq(
            stableBalanceInNewFarmBeforeTopUp,
            0,
            "Stable balance in new farm should be 0 after recovery"
        );

        assertGt(
            stableToken.balanceOf(
                address(newFarm)
            ),
            0,
            "Stable balance in new farm should be above 0 after topup"
        );

        vm.warp(
            block.timestamp + 365 days * 3
        );

        uint256 verseInFarmBeforeEveryoneExit = verseToken.balanceOf(
            address(newFarm)
        );

        // console.log(verseInFarmBeforeEveryoneExit, 'verseInFarmBeforeEveryoneExit');

        for (i = 0; i < l; i++) {

            address stakeOwner = migration.getAllocationStakeOwner(i);

            vm.startPrank(
                stakeOwner
            );

            uint256 rewardA = newFarm.earnedA(
                stakeOwner
            );

            uint256 rewardB = newFarm.earnedB(
                stakeOwner
            );

            uint256 unlockable = newFarm.unlockable(
                stakeOwner
            );

            uint256 userVerseBalanceBefore = verseToken.balanceOf(
                stakeOwner
            );

            uint256 userStableBalanceBefore = stableToken.balanceOf(
                stakeOwner
            );

            uint256 remainingBalanceVerse = verseToken.balanceOf(
                address(newFarm)
            );

            uint256 remainingBalanceStable = stableToken.balanceOf(
                address(newFarm)
            );

            newFarm.exitFarm();

            uint256 userVerseBalanceAfter = verseToken.balanceOf(
                stakeOwner
            );

            uint256 userStableBalanceAfter = stableToken.balanceOf(
                stakeOwner
            );

            uint256 remainingBalanceVerseAfter = verseToken.balanceOf(
                address(newFarm)
            );

            uint256 remainingBalanceStableAfter = stableToken.balanceOf(
                address(newFarm)
            );

            assertEq(
                remainingBalanceStable - rewardB,
                remainingBalanceStableAfter,
                "Correct amount of stable tokens"
            );

            assertGt(
                userVerseBalanceAfter,
                userVerseBalanceBefore,
                "User verse balance should be above 0"
            );

            assertGt(
                userStableBalanceAfter,
                userStableBalanceBefore,
                "User stable balance should be above 0"
            );

            assertEq(
                userVerseBalanceAfter,
                userVerseBalanceBefore + unlockable + rewardA
            );

            assertEq(
                userStableBalanceAfter,
                userStableBalanceBefore + rewardB
            );

            assertEq(
                remainingBalanceVerse,
                rewardA + unlockable + remainingBalanceVerseAfter,
                "Old balance should be new balnace + reward + unlcoked"
            );

            vm.stopPrank();
        }

        uint256 stablesInNewFarmAfterEveryoneExit = stableToken.balanceOf(
            address(newFarm)
        );

        assertLt(
            stablesInNewFarmAfterEveryoneExit,
            100, // just dust remain
            "Stable tokens should be 0 after everyone exits"
        );

        uint256 verseInFarmAfterEveryoneExit = verseToken.balanceOf(
            address(newFarm)
        );

        // console.log(verseInFarmAfterEveryoneExit, 'verseInFarmAfterEveryoneExit');

        assertGt(
            verseInFarmAfterEveryoneExit,
            0, // expecting some verse to remain
            "Verse in farm should be above 0 after everyone exits"
        );

        assertGt(
            verseInFarmBeforeEveryoneExit,
            verseInFarmAfterEveryoneExit,
            "Verse in farm should reduce"
        );

        vm.stopPrank();
    }
}
