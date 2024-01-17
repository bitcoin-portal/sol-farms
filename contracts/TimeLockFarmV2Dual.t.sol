// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.23;

import "forge-std/Test.sol";

import "./TestToken.sol";
import "./ManagerSetup.sol";
import "./TimeLockFarmV2Dual.sol";

contract TimeLockFarmV2DualTest is Test {

    TimeLockFarmV2Dual public farm;
    ManagerSetup public manager;

    TestToken public verseToken;
    TestToken public stableToken;

    uint256 constant FORK_MAINNET_BLOCK = 51_881_427;

    address constant ADMIN_ADDRESS = address(
        0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689
    );

    address constant USER_ADDRESS = address(
        0x127564F78d371ECcE6Ab86A179Be4e4378B6ea3D
    );

    address constant ZERO_ADDRESS = address(0x0);
    uint256 public constant DEFAULT_DURATION = 30 days;

    function tokens(
        uint256 _amount
    )
        internal
        pure
        returns (uint256)
    {
        return _amount * 10 ** 18;
    }

    function _simpleForwardTime()
        internal
    {
        vm.warp(
            block.timestamp + 1 days
        );

        vm.roll(
            block.number + 100
        );
    }

    function setUp()
        public
    {
        vm.createSelectFork(
            vm.rpcUrl("polygon"),
            FORK_MAINNET_BLOCK
        );

        // @TODO test without
        vm.warp(1704067200);

        vm.startPrank(
            ADMIN_ADDRESS
        );

        verseToken = new TestToken();
        stableToken = new TestToken();

        farm = new TimeLockFarmV2Dual({
            _stakeToken: IERC20(address(verseToken)),
            _rewardTokenA: IERC20(address(verseToken)),
            _rewardTokenB: IERC20(address(stableToken)),
            _defaultDuration: DEFAULT_DURATION
        });

        vm.expectRevert(
            "TimeLockFarmV2Dual: NO_STAKERS"
        );

        farm.setRewardRates(
            tokens(1),
            tokens(1)
        );

        manager = new ManagerSetup({
            _owner: ADMIN_ADDRESS,
            _worker: ADMIN_ADDRESS,
            _timeLockFarm: address(farm)
        });

        verseToken.transfer(
            address(manager),
            tokens(6_481_250_000)
        );

        farm.changeManager(
            address(manager)
        );

        manager.executeAllocations();

        vm.expectRevert(
            "ManagerSetup: ALREADY_INITIALIZED"
        );

        manager.executeAllocations();

        vm.stopPrank();
    }

    function testChangeDuration()
        public
    {
        uint256 expectedDuration = DEFAULT_DURATION;
        uint256 updatedDuration = 60 days;

        uint256 duration = farm.rewardDuration();

        vm.startPrank(
            ADMIN_ADDRESS
        );

        farm.changeManager(
            address(ADMIN_ADDRESS)
        );

        assertEq(
            duration,
            expectedDuration
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_DURATION"
        );

        farm.setRewardDuration(
            0
        );

        farm.setRewardDuration(
            updatedDuration
        );

        duration = farm.rewardDuration();

        assertEq(
            duration,
            updatedDuration
        );
    }

    function testDestroyStaker()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        address staker = 0x6fEeB0c3E25E5dEf17BC7274406F0674B8237038;

        _simpleForwardTime();

        farm.destroyStaker(
            true,
            true,
            ADMIN_ADDRESS
        );

        uint256 balanceBefore = verseToken.balanceOf(
            staker
        );

        uint256 unlockableAmount = farm.unlockable(
            staker
        );

        assertGt(
            unlockableAmount,
            0,
            "Unlockable amount should be above 0"
        );

        assertEq(
            balanceBefore,
            0,
            "Farm balance should be 0"
        );

        farm.destroyStaker(
            true,
            true,
            staker
        );

        uint256 balanceAfter = verseToken.balanceOf(
            staker
        );

        assertEq(
            balanceAfter,
            unlockableAmount,
            "Farm balance should be above 0"
        );

        uint256 stakeCount = farm.stakeCount(
            staker
        );

        assertEq(
            stakeCount,
            0,
            "Stake count should be 0"
        );
    }

    function testMakeDepositForUser()
        public
    {
        uint256 depositAmount = tokens(100_000);

        vm.startPrank(
            ADMIN_ADDRESS
        );

        verseToken.approve(
            address(farm),
            depositAmount
        );

        uint256 balanceBefore = verseToken.balanceOf(
            address(farm)
        );

        farm.changeManager(
            address(ADMIN_ADDRESS)
        );

        farm.makeDepositForUser(
            ADMIN_ADDRESS,
            depositAmount,
            DEFAULT_DURATION,
            block.timestamp
        );

        uint256 balanceAfter = verseToken.balanceOf(
            address(farm)
        );

        assertEq(
            balanceAfter - balanceBefore,
            depositAmount
        );
    }

    function testMakeDepositForUserWithZero()
        public
    {
        uint256 depositAmount = tokens(0);

        vm.startPrank(
            ADMIN_ADDRESS
        );

        verseToken.approve(
            address(farm),
            depositAmount
        );

        uint256 balanceBefore = verseToken.balanceOf(
            address(farm)
        );

        farm.changeManager(
            address(ADMIN_ADDRESS)
        );

        uint256 userStake = farm.stakeCount(
            ADMIN_ADDRESS
        );

        uint256 expectedCountBefore = 2;

        assertEq(
            userStake,
            expectedCountBefore
        );

        farm.makeDepositForUser(
            ADMIN_ADDRESS,
            depositAmount,
            DEFAULT_DURATION,
            0
        );

        userStake = farm.stakeCount(
            ADMIN_ADDRESS
        );

        assertEq(
            userStake,
            expectedCountBefore + 1
        );

        uint256 balanceAfter = verseToken.balanceOf(
            address(farm)
        );

        assertEq(
            balanceAfter - balanceBefore,
            depositAmount
        );
    }

    function testMakeDepositForUserThroughManager()
        public
    {
        uint256 depositAmount = tokens(100_000);

        vm.startPrank(
            ADMIN_ADDRESS
        );

        verseToken.transfer(
            address(manager),
            depositAmount
        );

        uint256 balanceBefore = verseToken.balanceOf(
            address(farm)
        );

        manager.makeDepositForUser({
            _stakeOwner: ADMIN_ADDRESS,
            _stakeAmount: depositAmount,
            _lockingTime: DEFAULT_DURATION,
            _initialTime: block.timestamp
        });

        uint256 balanceAfter = verseToken.balanceOf(
            address(farm)
        );

        assertEq(
            balanceAfter - balanceBefore,
            depositAmount
        );
    }

    function testProposeNewOwner()
        public
    {
        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_OWNER"
        );

        farm.proposeNewOwner(
            USER_ADDRESS
        );

        vm.startPrank(
            ADMIN_ADDRESS
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: WRONG_ADDRESS"
        );

        farm.proposeNewOwner(
            ZERO_ADDRESS
        );

        farm.proposeNewOwner(
            USER_ADDRESS
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_CANDIDATE"
        );

        farm.claimOwnership();

        address proposed = farm.proposedOwner();

        assertEq(
            proposed,
            USER_ADDRESS
        );

        vm.startPrank(
            USER_ADDRESS
        );

        farm.claimOwnership();

        address newOwner = farm.ownerAddress();

        assertEq(
            newOwner,
            USER_ADDRESS
        );
    }

    function testChangeManager()
        public
    {
        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_OWNER"
        );

        farm.changeManager(
            USER_ADDRESS
        );

        vm.startPrank(
            ADMIN_ADDRESS
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: WRONG_ADDRESS"
        );

        farm.changeManager(
            ZERO_ADDRESS
        );

        farm.changeManager(
            USER_ADDRESS
        );

        address newManager = farm.managerAddress();

        assertEq(
            newManager,
            USER_ADDRESS
        );
    }

    function testLastTimeRewardApplicable()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        assertEq(
            farm.lastTimeRewardApplicable(),
            0,
            "Last time reward applicable should be 0"
        );

        testFastForwardWithRewards();

        assertGt(
            farm.lastTimeRewardApplicable(),
            0,
            "Last time reward applicable should be above 0"
        );
    }

    function testFarmExit()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        uint256 farmBalanceForUserBefore = farm.balanceOf(
            ADMIN_ADDRESS
        );

        farm.exitFarm();

        uint256 farmBalanceForUserAfter = farm.balanceOf(
            ADMIN_ADDRESS
        );

        uint256 expectedWithdraw = farmBalanceForUserBefore
            * 20
            / 100;

        // @TODO test with timewarp
        // vm.warp(1704067200);

        assertEq(
            farmBalanceForUserBefore,
            farmBalanceForUserAfter + expectedWithdraw,
            "Farm balance for user should be 20% less after exit"
        );
    }

    function testScraping()
        public
    {
        address withdrawAddress = ADMIN_ADDRESS;

        uint256 availableToWithdrawInitially = farm.unlockable(
            withdrawAddress
        );

        _simpleForwardTime();

        uint256 availableToWithdrawNow = farm.unlockable(
            withdrawAddress
        );

        console.log(availableToWithdrawNow, 'availableToWithdrawNow');

        vm.startPrank(
            withdrawAddress
        );

        uint256 tokensInWalletBeforeExit = farm.balanceOf(
            withdrawAddress
        );

        farm.exitFarm();

        uint256 tokensInWalletAfterExit = farm.balanceOf(
            withdrawAddress
        );

        assertEq(
            tokensInWalletBeforeExit,
            tokensInWalletAfterExit + availableToWithdrawNow,
            "Expected amount to withdraw must end up in user wallet"
        );

        uint256 availableToWithdrawAfterExit = farm.unlockable(
            withdrawAddress
        );

        assertEq(
            availableToWithdrawAfterExit,
            0,
            "After user exited counter of unlockable must be 0"
        );

        _simpleForwardTime();

        availableToWithdrawAfterExit = farm.unlockable(
            withdrawAddress
        );

        console.log(
            availableToWithdrawAfterExit,
            'availableToWithdrawAfterExit'
        );

        console.log(
            availableToWithdrawNow - availableToWithdrawAfterExit,
            'availableToWithdrawAfterExit'
        );

        assertGt(
            availableToWithdrawAfterExit,
            0,
            "Once time passed amount should increase"
        );

        /*
        vm.warp(1704067200);
        assertEq(
            availableToWithdrawNow - availableToWithdrawAfterExit,
            tokens(37500000),
            "Compare with initial amount hardcoded"
        );
        */

        assertEq(
            availableToWithdrawNow - availableToWithdrawAfterExit,
            availableToWithdrawInitially,
            "Compare with initial amount"
        );
    }

    function testFastForward()
        public
    {
        uint256 expectedDuration = 365 days * 4 + 3 days;

        vm.warp(
            block.timestamp + expectedDuration
        );

        vm.startPrank(
            ADMIN_ADDRESS
        );

        uint256 stakeCountBefore = farm.stakeCount(
            ADMIN_ADDRESS
        );

        assertEq(
            stakeCountBefore,
            2,
            "User should have 2 stakes initially"
        );

        uint256 availableToWithdrawBefore = farm.unlockable(
            ADMIN_ADDRESS
        );

        assertGt(
            availableToWithdrawBefore,
            0,
            "User should have unlockable balance as 0"
        );

        uint256 userBalanceBefore = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        uint256 userBalanceBeforeB = stableToken.balanceOf(
            ADMIN_ADDRESS
        );

        uint256 rewardsExpectedA = farm.earnedA(
            ADMIN_ADDRESS
        );

        uint256 rewardsExpectedB = farm.earnedB(
            ADMIN_ADDRESS
        );

        farm.exitFarm();

        uint256 userBalanceAfter = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        uint256 userBalanceAfterB = stableToken.balanceOf(
            ADMIN_ADDRESS
        );

        assertEq(
            userBalanceAfter - userBalanceBefore,
            availableToWithdrawBefore + rewardsExpectedA,
            "User should have unlockable balance + rewards token A"
        );

        assertEq(
            userBalanceAfterB - userBalanceBeforeB,
            rewardsExpectedB,
            "User should have rewards for token B"
        );

        uint256 availableToWithdrawAfter = farm.unlockable(
            ADMIN_ADDRESS
        );

        assertEq(
            availableToWithdrawAfter,
            0,
            "User should have 0 unlockable balance"
        );

        uint256 stakeCountAfter = farm.stakeCount(
            ADMIN_ADDRESS
        );

        assertEq(
            stakeCountAfter,
            0,
            "User should have 0 stakes remaining"
        );

        uint256 userBalanceAgain = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        farm.exitFarm();

        uint256 userBalanceCheck = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        assertEq(
            userBalanceAgain,
            userBalanceCheck,
            "Users balance should not change"
        );
    }

    function testFastForwardWithRewards()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        verseToken.transfer(
            address(manager),
            tokens(100_000_000_000)
        );

        stableToken.transfer(
            address(manager),
            tokens(200_000_000_000)
        );

        manager.setWorker(
            ADMIN_ADDRESS
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_RATE_A"
        );

        manager.setRewardRates(
            tokens(0),
            tokens(1)
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_RATE_B"
        );

        manager.setRewardRates(
            tokens(1),
            tokens(0)
        );

        manager.setRewardRates(
            tokens(1),
            tokens(1)
        );

        manager.setRewardRates(
            tokens(2),
            tokens(2)
        );

        uint256 globalsLocked = farm.globalLocked({
            _squared: false
        });

        uint256 globalsLockedSQRT = farm.globalLocked({
            _squared: true
        });

        assertGt(
            globalsLocked,
            0,
            "Globals should be above 0"
        );

        assertGt(
            globalsLockedSQRT,
            0,
            "Globals should be above 0"
        );

        testFastForward();

        uint256 globalsLockedAfter = farm.globalLocked({
            _squared: false
        });

        uint256 globalsLockedSQRTAfter = farm.globalLocked({
            _squared: true
        });

        assertEq(
            globalsLockedAfter,
            0,
            "Globals should be 0"
        );

        assertEq(
            globalsLockedSQRTAfter,
            0,
            "Globals should be 0"
        );
    }

    function testRewardPerToken()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        uint256 rewardPerTokenA = farm.rewardPerTokenA();

        assertEq(
            rewardPerTokenA,
            0,
            "Reward per token should be 0"
        );

        uint256 rewardPerTokenB = farm.rewardPerTokenB();

        assertEq(
            rewardPerTokenB,
            0,
            "Reward per token should be 0"
        );

        testFastForwardWithRewards();

        rewardPerTokenA = farm.rewardPerTokenA();

        assertGt(
            rewardPerTokenA,
            0,
            "Reward per token should be above 0"
        );

        rewardPerTokenB = farm.rewardPerTokenB();

        assertGt(
            rewardPerTokenB,
            0,
            "Reward per token should be above 0"
        );
    }

    function testIsProtected()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        bool isProtected = farm.isProtected(
            ADMIN_ADDRESS
        );

        assertEq(
            isProtected,
            false,
            "User should not be protected"
        );

        farm.protectStaker(
            ADMIN_ADDRESS
        );

        isProtected = farm.isProtected(
            ADMIN_ADDRESS
        );

        assertEq(
            isProtected,
            true,
            "User should be protected"
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: PROTECTED"
        );

        farm.destroyStaker(
            true,
            true,
            ADMIN_ADDRESS
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: PROTECTED"
        );

        farm.destroyStaker(
            false,
            true,
            ADMIN_ADDRESS
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: PROTECTED"
        );

        farm.destroyStaker(
            true,
            false,
            ADMIN_ADDRESS
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: PROTECTED"
        );

        farm.destroyStaker(
            false,
            false,
            ADMIN_ADDRESS
        );
    }

    function testDestroyStakerTakeRewards()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        address destroyedStaker = USER_ADDRESS;

        uint256 farmTokensByAdminBefore = farm.balanceOf(
            ADMIN_ADDRESS
        );

        assertGt(
            farmTokensByAdminBefore,
            0,
            "User should have some farm tokens"
        );

        uint256 farmTokensByStakerBefore = farm.balanceOf(
            destroyedStaker
        );

        assertGt(
            farmTokensByStakerBefore,
            0,
            "User should have some farm tokens"
        );

        uint256 rewardTokenBefore = verseToken.balanceOf(
            destroyedStaker
        );

        uint256 userBalanceBeforeStable = stableToken.balanceOf(
            destroyedStaker
        );

        uint256 stakesOfUser = farm.stakeCount(
            destroyedStaker
        );

        assertEq(
            stakesOfUser,
            2,
            "User should have 2 stakes initially"
        );

        uint256 stakesOfAdminBefore = farm.stakeCount(
            ADMIN_ADDRESS
        );

        assertEq(
            stakesOfAdminBefore,
            2,
            "Admin should have 2 stakes initially"
        );

        farm.destroyStaker({
            _allowFarmWithdraw: false,
            _allowClaimRewards: false,
            _withdrawAddress: destroyedStaker
        });

        uint256 farmTokensByAdminAfter = farm.balanceOf(
            ADMIN_ADDRESS
        );

        assertEq(
            farmTokensByAdminAfter,
            farmTokensByAdminBefore + farmTokensByStakerBefore,
            "Admin should get all users tokens"
        );

        uint256 farmTokensByStakerAfter = farm.balanceOf(
            destroyedStaker
        );

        assertEq(
            farmTokensByStakerAfter,
            0,
            "User should have 0 farm tokens after user destroyed"
        );

        uint256 stakesOfUserAfter = farm.stakeCount(
            destroyedStaker
        );

        assertEq(
            stakesOfUserAfter,
            0,
            "User should have 0 stakes after user destroyed"
        );

        uint256 stakesOfAdmin = farm.stakeCount(
            ADMIN_ADDRESS
        );

        assertEq(
            stakesOfAdmin,
            stakesOfAdminBefore + 1,
            "Admin stakes should increase by 1"
        );

        uint256 rewardTokenAfter = verseToken.balanceOf(
            destroyedStaker
        );

        uint256 userBalanceAfterStable = stableToken.balanceOf(
            destroyedStaker
        );

        assertEq(
            rewardTokenAfter,
            rewardTokenBefore,
            "User should not get any tokens"
        );

        assertEq(
            userBalanceAfterStable,
            userBalanceBeforeStable,
            "User should not get any stable rewards"
        );
    }

    function testRenounceOwnership()
        public
    {
        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_OWNER"
        );

        farm.renounceOwnership();

        vm.startPrank(
            ADMIN_ADDRESS
        );

        farm.renounceOwnership();

        address newOwner = farm.ownerAddress();

        assertEq(
            newOwner,
            ZERO_ADDRESS
        );
    }

    function testRecoverTokens()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        uint256 balanceBefore = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        farm.recoverTokens(
            IERC20(address(verseToken)),
            tokens(1)
        );

        uint256 balanceAfter = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        assertEq(
            balanceAfter - balanceBefore,
            tokens(1)
        );

        stableToken.transfer(
            address(farm),
            tokens(2)
        );

        farm.recoverTokens(
            IERC20(address(stableToken)),
            tokens(1)
        );

        farm.renounceRewardTokenRecovery();

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_RECOVERY"
        );

        farm.recoverTokens(
            IERC20(address(verseToken)),
            tokens(1)
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_RECOVERY"
        );

        farm.recoverTokens(
            IERC20(address(stableToken)),
            tokens(1)
        );

        vm.stopPrank();

        vm.startPrank(
            farm.managerAddress()
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_OWNER"
        );

        farm.recoverTokens(
            IERC20(address(verseToken)),
            tokens(1)
        );
    }

    function testClaimRewards()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        stableToken.transfer(
            address(manager),
            tokens(100_000_000_000)
        );

        manager.setRewardRates(
            tokens(1),
            tokens(1)
        );

        _simpleForwardTime();

        uint256 rewardTokenBefore = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        uint256 userBalanceBeforeStable = stableToken.balanceOf(
            ADMIN_ADDRESS
        );

        farm.claimReward();

        uint256 rewardTokenAfter = verseToken.balanceOf(
            ADMIN_ADDRESS
        );

        uint256 userBalanceAfterStable = stableToken.balanceOf(
            ADMIN_ADDRESS
        );

        assertGt(
            rewardTokenAfter,
            rewardTokenBefore,
            "User should get some tokens"
        );

        assertGt(
            userBalanceAfterStable,
            userBalanceBeforeStable,
            "User should get some stable rewards"
        );
    }

    function testTransfer()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        uint256 balanceBefore = farm.balanceOf(
            ADMIN_ADDRESS
        );

        farm.transfer(
            USER_ADDRESS,
            tokens(1)
        );

        uint256 balanceAfter = farm.balanceOf(
            ADMIN_ADDRESS
        );

        assertEq(
            balanceBefore - balanceAfter,
            tokens(1)
        );
    }

    function testSetAllowTransfer()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        farm.setAllowTransfer(
            false
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: TRANSFER_LOCKED"
        );

        farm.transfer(
            USER_ADDRESS,
            tokens(1)
        );

        farm.setAllowTransfer(
            true
        );

        farm.transfer(
            USER_ADDRESS,
            tokens(1)
        );
    }

    function testTransferFrom()
        public
    {
        vm.startPrank(
            USER_ADDRESS
        );

        farm.approve(
            ADMIN_ADDRESS,
            tokens(1)
        );

        uint256 balanceBefore = farm.balanceOf(
            ADMIN_ADDRESS
        );

        vm.stopPrank();

        vm.startPrank(
            ADMIN_ADDRESS
        );

        farm.setAllowTransfer(
            false
        );

        vm.expectRevert(
            "TimeLockFarmV2Dual: TRANSFER_LOCKED"
        );

        farm.transferFrom(
            USER_ADDRESS,
            ADMIN_ADDRESS,
            tokens(1)
        );

        farm.setAllowTransfer(
            true
        );

        farm.transferFrom(
            USER_ADDRESS,
            ADMIN_ADDRESS,
            tokens(1)
        );

        uint256 balanceAfter = farm.balanceOf(
            ADMIN_ADDRESS
        );

        assertEq(
            balanceAfter - balanceBefore,
            tokens(1)
        );
    }

    function testFarmWithdraw()
        public
    {
        address withdrawAddress = USER_ADDRESS;

        vm.startPrank(
            withdrawAddress
        );

        uint256 farmBalanceForUserBefore = farm.balanceOf(
            withdrawAddress
        );

        uint256 withdrawAmount = farmBalanceForUserBefore / 10;

        farm.farmWithdraw(
            withdrawAmount
        );

        uint256 farmBalanceForUserAfter = farm.balanceOf(
            withdrawAddress
        );

        assertEq(
            farmBalanceForUserBefore,
            farmBalanceForUserAfter + withdrawAmount
        );
    }

    function testClearPastStamps()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        uint256 stampsBefore = farm.uniqueStamps(0);

        assertGt(
            stampsBefore,
            0,
            "Stamps should be above 0"
        );

        farm.clearPastStamps();

        uint256 stampsAfter = farm.uniqueStamps(0);

        assertGt(
            stampsBefore,
            0,
            "Stamps should be above 0"
        );

        assertGt(
            stampsAfter,
            0,
            "Stamps should be above 0"
        );

        testFastForward();

        stampsBefore = farm.uniqueStamps(0);

        uint256 rateBefore = farm.unlockRates(
            stampsBefore
        );

        assertEq(
            stampsBefore,
            1830211200,
            "Stamps should be 1830211200"
        );

        assertGt(
            rateBefore,
            0,
            "Rate should be above 0"
        );

        farm.clearPastStamps();

        uint256 rateAfter = farm.unlockRates(
            stampsBefore
        );

        assertEq(
            rateAfter,
            0,
            "Rate should be 0"
        );

        vm.warp(
            block.timestamp + 365 days
        );

        uint256 l = farm.getStampsLength();

        assertEq(
            l,
            6,
            "Stamps length should be 6"
        );

        farm.clearPastStamps();

        vm.warp(
            block.timestamp + 365 days
        );

        farm.clearPastStamps();

        l = farm.getStampsLength();

        assertEq(
            l,
            1,
            "Stamps length should be 1"
        );

        vm.warp(
            block.timestamp + 365 days
        );

        farm.clearPastStamps();

        l = farm.getStampsLength();

        assertEq(
            l,
            0,
            "Stamps length should be 0"
        );
    }
}
