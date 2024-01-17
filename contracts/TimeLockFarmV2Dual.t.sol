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

    uint256 public constant DEFAULT_DURATION = 30 days;

    function tokens(uint256 _amount)
        internal
        view
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

        _simpleForwardTime();

        farm.destroyStaker(
            ADMIN_ADDRESS
        );

        farm.destroyStaker(
            0x6fEeB0c3E25E5dEf17BC7274406F0674B8237038
        );

        uint256 balance = verseToken.balanceOf(
            address(farm)
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

    function testFarmWithdraw()
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
}
