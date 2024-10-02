// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

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

    address constant FUTURE_ADDRES = address(
        0x216b6F99CA2bf53d801fE9Ba7d68fADC4949249B
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
            tokens(6_676_240_000)
        );

        farm.changeManager(
            address(manager)
        );

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

        vm.expectRevert(
            "TimeLockFarmV2Dual: INVALID_TIME"
        );

        farm.makeDepositForUser(
            ADMIN_ADDRESS,
            depositAmount,
            DEFAULT_DURATION,
            block.timestamp + 1
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

        vm.warp(
            block.timestamp + 365 days * 4
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
            * 21
            / 100;

        assertApproxEqRel(
            farmBalanceForUserBefore,
            farmBalanceForUserAfter + expectedWithdraw,
            1E16,
            "Farm balance for user should be approx 20% less after exit"
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

    function testMakeDepositForUserWorks()
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

    function testAbilityDestroyFutureStaker()
        public
    {
        vm.startPrank(
            ADMIN_ADDRESS
        );

        uint256 balanceBefore = farm.balanceOf(
            FUTURE_ADDRES
        );

        assertEq(
            balanceBefore,
            0,
            "User should have not have some shares"
        );

        uint256 stakeCountBefore = farm.stakeCount(
            FUTURE_ADDRES
        );

        assertEq(
            stakeCountBefore,
            0,
            "User should have 0 stakes initially"
        );

        uint256 availableToWithdrawBefore = farm.unlockable(
            FUTURE_ADDRES
        );

        assertEq(
            availableToWithdrawBefore,
            0,
            "User should have unlockable balance as 0"
        );

        vm.startPrank(
            ADMIN_ADDRESS
        );

        farm.destroyStaker(
            false,
            false,
            FUTURE_ADDRES
        );

        uint256 balanceAfter = farm.balanceOf(
            FUTURE_ADDRES
        );

        assertEq(
            balanceAfter,
            0,
            "User should have 0 shares"
        );

        uint256 stakeCountAfter = farm.stakeCount(
            FUTURE_ADDRES
        );

        assertEq(
            stakeCountAfter,
            0,
            "User should have 0 stakes"
        );

        uint256 availableToWithdrawAfter = farm.unlockable(
            FUTURE_ADDRES
        );

        assertEq(
            availableToWithdrawAfter,
            0,
            "User should have unlockable balance as 0"
        );

        vm.startPrank(
            ADMIN_ADDRESS
        );

        farm.changeManager(
            ADMIN_ADDRESS
        );

        verseToken.approve(
            address(farm),
            tokens(100_000)
        );

        farm.makeDepositForUser(
            FUTURE_ADDRES,
            tokens(100_000),
            DEFAULT_DURATION,
            block.timestamp
        );

        uint256 stakeCountAfterDeposit = farm.stakeCount(
            FUTURE_ADDRES
        );

        assertEq(
            stakeCountAfterDeposit,
            1,
            "User should have 1 stake"
        );

        uint256 availableToWithdrawAfterDeposit = farm.unlockable(
            FUTURE_ADDRES
        );

        assertEq(
            availableToWithdrawAfterDeposit,
            0,
            "User should have unlockable balance as 0"
        );

        vm.warp(
            block.timestamp + 365 days
        );

        uint256 availableToWithdrawAfterWarp = farm.unlockable(
            FUTURE_ADDRES
        );

        assertGt(
            availableToWithdrawAfterWarp,
            0,
            "User should have unlockable balance above 0"
        );

        farm.destroyStaker(
            false,
            false,
            FUTURE_ADDRES
        );

        vm.stopPrank();
    }
}
