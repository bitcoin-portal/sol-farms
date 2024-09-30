// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./DynamicRewardFarm.sol";
import "./TestToken.sol";

contract DynamicRewardFarmTest is Test {

    address constant DEAD_ADDRESS = address(
        0x000000000000000000000000000000000000dEaD
    );

    DynamicRewardFarm public farm;
    TestToken public stakeToken;
    TestToken public rewardTokenA;
    TestToken public rewardTokenB;
    TestToken public rewardTokenC;

    address public owner = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);

    uint256 public defaultRewardRate = 1e18; // 1 token per second
    uint256 public defaultDuration = 30 days;
    uint256 constant PRECISIONS = 1e18;

    function setUp() public {
        // Deploy tokens with 'owner' as the master
        vm.startPrank(owner);
        stakeToken = new TestToken();
        rewardTokenA = new TestToken();
        rewardTokenB = new TestToken();
        rewardTokenC = new TestToken();
        vm.stopPrank();

        // Initialize the farm
        vm.startPrank(owner);
        farm = new DynamicRewardFarm();
        farm.initialize(
            address(stakeToken),
            defaultDuration,
            owner,
            owner,
            "Farm Receipt Token",
            "FARM"
        );
        vm.stopPrank();

        // Mint and distribute tokens to users
        vm.startPrank(owner);
        // Mint tokens to users using 'mintByMaster'
        stakeToken.mintByMaster(1000e18, user1);
        stakeToken.mintByMaster(1000e18, user2);

        // Mint reward tokens to 'owner' for distribution
        rewardTokenA.mintByMaster(1e27, owner); // Mint 1e27 tokens to owner
        rewardTokenB.mintByMaster(1e27, owner);
        vm.stopPrank();

        // Users approve farm to spend stake tokens
        vm.prank(user1);
        stakeToken.approve(address(farm), type(uint256).max);

        vm.prank(user2);
        stakeToken.approve(address(farm), type(uint256).max);

        // Owner adds reward tokens
        vm.startPrank(owner);
        farm.addRewardToken(address(rewardTokenA));
        farm.addRewardToken(address(rewardTokenB));
        vm.stopPrank();

        // Owner approves farm to spend reward tokens
        vm.startPrank(owner);
        rewardTokenA.approve(address(farm), type(uint256).max);
        rewardTokenB.approve(address(farm), type(uint256).max);

        // Manager sets reward rates using dynamic arrays
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(rewardTokenA);
        rewardTokens[1] = address(rewardTokenB);

        uint256[] memory rewardRates = new uint256[](2);
        rewardRates[0] = defaultRewardRate;
        rewardRates[1] = defaultRewardRate;

        farm.setRewardRates(rewardTokens, rewardRates);
        vm.stopPrank();
    }

    function testStakeAndEarnRewards() public {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18); // Stake 100 tokens

        // Fast forward time
        vm.warp(block.timestamp + 100);

        // User1 claims rewards
        vm.prank(user1);
        farm.claimRewards();

        // Check that user1 received rewards
        uint256 earnedA = rewardTokenA.balanceOf(user1);
        uint256 earnedB = rewardTokenB.balanceOf(user1);

        assertGt(earnedA, 0, "User1 should have earned Reward Token A");
        assertGt(earnedB, 0, "User1 should have earned Reward Token B");

        // earned by DEAD_ADDRESS
        uint256 earnedADeadA = farm.earnedByToken(
            address(rewardTokenA),
            DEAD_ADDRESS
        );

        uint256 earnedADeadB = farm.earnedByToken(
            address(rewardTokenB),
            DEAD_ADDRESS
        );

        // Check that the amount is approximately correct
        uint256 expectedRewards = defaultRewardRate * 100; // Reward rate per second * time
        assertApproxEqAbs(earnedA, expectedRewards - earnedADeadA, 1e17, "User1 should have earned correct amount of Reward Token A");
        assertApproxEqAbs(earnedB, expectedRewards - earnedADeadB, 1e17, "User1 should have earned correct amount of Reward Token B");
    }

    function testMultipleUsersStaking() public {
        // User1 stakes 100 tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // Advance time by 50 seconds
        vm.warp(block.timestamp + 50);

        // User2 stakes 200 tokens
        vm.prank(user2);
        farm.farmDeposit(200e18);

        // Advance time by 50 seconds
        vm.warp(block.timestamp + 50);

        // Users claim rewards
        vm.prank(user1);
        farm.claimRewards();

        vm.prank(user2);
        farm.claimRewards();

        // Check rewards
        uint256 earnedAUser1 = rewardTokenA.balanceOf(user1);
        uint256 earnedAUser2 = rewardTokenA.balanceOf(user2);

        // Allow for some margin due to time differences
        assertGt(earnedAUser2, earnedAUser1 / 2, "User2 should have earned more than half of User1's rewards");
        assertGt(earnedAUser2, 0, "User2 should have earned some rewards");
    }

    function testWithdrawStake() public {
        // User1 stakes 100 tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // Advance time
        vm.warp(block.timestamp + 50);

        // User1 withdraws 50 tokens
        vm.prank(user1);
        farm.farmWithdraw(50e18);

        // Check balances
        uint256 farmBalance = farm.balanceOf(user1);
        assertEq(farmBalance, 50e18, "User1 should have 50 tokens staked");

        // Advance time
        vm.warp(block.timestamp + 50);

        // User1 claims rewards
        vm.prank(user1);
        farm.claimRewards();

        // Check that rewards are greater than zero
        uint256 earnedA = rewardTokenA.balanceOf(user1);
        assertGt(earnedA, 0, "User1 should have earned some rewards");
    }

    function testAddNewRewardToken() public {
        // Owner adds reward token C
        vm.prank(owner);
        farm.addRewardToken(address(rewardTokenC));

        // Owner approves farm to spend reward token C
        vm.startPrank(owner);
        rewardTokenC.mintByMaster(1e27, owner);
        rewardTokenC.approve(address(farm), type(uint256).max);
        vm.stopPrank();

        // Manager sets reward rates using dynamic arrays
        // Get current reward tokens from the farm
        address[] memory rewardTokens = farm.getRewardTokens();

        // Update rewardRates array to match the length of rewardTokens
        uint256[] memory rewardRates = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardRates[i] = defaultRewardRate;
        }

        vm.prank(owner);
        farm.setRewardRates(rewardTokens, rewardRates);

        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // Advance time
        vm.warp(block.timestamp + 100);

        // User1 claims rewards
        vm.prank(user1);
        farm.claimRewards();

        // Check that user1 received rewards for reward token C
        uint256 earnedC = rewardTokenC.balanceOf(user1);
        assertGt(earnedC, 0, "User1 should have earned Reward Token C");
    }

    function testOwnershipTransfer() public {
        // Owner proposes new owner
        vm.prank(owner);
        farm.proposeNewOwner(user1);

        // User1 claims ownership
        vm.prank(user1);
        farm.claimOwnership();

        // Check that ownerAddress is now user1
        address newOwner = farm.ownerAddress();
        assertEq(newOwner, user1, "Owner should be updated to user1");

        // User1 tries to add a reward token (should succeed)
        vm.prank(user1);
        farm.addRewardToken(address(rewardTokenC));
    }

    function testManagerFunctions() public {
        uint256 currentDuratoin = farm.rewardDuration();
        vm.warp(block.timestamp + currentDuratoin * 2);
        // Manager changes reward duration
        vm.prank(owner);
        farm.setRewardDuration(60 days);

        uint256 newDuration = farm.rewardDuration();
        assertEq(newDuration, 60 days, "Reward duration should be updated to 60 days");

        // Manager sets new reward rates using dynamic arrays
        address[] memory rewardTokens = farm.getRewardTokens();
        uint256[] memory rewardRates = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardRates[i] = defaultRewardRate * 2;
        }

        vm.prank(owner);
        farm.setRewardRates(rewardTokens, rewardRates);

        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // Advance time
        vm.warp(block.timestamp + 100);

        // User1 claims rewards
        vm.prank(user1);
        farm.claimRewards();

        // @TODO: check this
        // Check that user1 received approximately double the rewards
        // uint256 earnedA = rewardTokenA.balanceOf(user1);
        // uint256 expectedRewards = defaultRewardRate * 2 * 100;

        // Allow some margin
        // @TODO: check this
        // assertApproxEqAbs(earnedA, expectedRewards, 1e17, "User1 should have earned correct amount of Reward Token A at new rate");
    }

    function testRecoverToken() public {
        // Owner tries to recover an unrelated token
        vm.startPrank(owner);
        TestToken randomToken = new TestToken();
        uint256 ownerBalanceBefore = randomToken.balanceOf(owner);
        randomToken.mintByMaster(1000e18, address(farm));
        vm.stopPrank();

        uint256 farmBalanceBefore = randomToken.balanceOf(address(farm));

        vm.prank(owner);
        farm.recoverToken(
            address(randomToken),
            500e18
        );

        uint256 farmBalanceAfter = randomToken.balanceOf(address(farm));
        uint256 ownerBalanceAfter = randomToken.balanceOf(owner);

        assertEq(farmBalanceAfter, farmBalanceBefore - 500e18, "Farm should have 500 less random tokens");
        assertEq(ownerBalanceAfter - ownerBalanceBefore, 500e18, "Owner should have recovered 500 random tokens");
    }

    function testCannotRecoverStakeOrRewardTokens() public {
        // Owner tries to recover stake token
        vm.prank(owner);
        vm.expectRevert("DynamicRewardFarm: STAKE_TOKEN");
        farm.recoverToken(address(stakeToken), 100e18);

        // Owner tries to recover reward token
        vm.prank(owner);
        vm.expectRevert("DynamicRewardFarm: NOT_ENOUGH_REWARDS");
        farm.recoverToken(address(rewardTokenA), 100e18);
    }

    function testTransferReceiptTokens() public {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // User1 transfers receipt tokens to User2
        vm.prank(user1);
        farm.transfer(user2, 50e18);

        // Check balances
        uint256 balanceUser1 = farm.balanceOf(user1);
        uint256 balanceUser2 = farm.balanceOf(user2);

        assertEq(balanceUser1, 50e18, "User1 should have 50 receipt tokens");
        assertEq(balanceUser2, 50e18, "User2 should have 50 receipt tokens");

        // Advance time
        vm.warp(block.timestamp + 100);

        // Both users claim rewards
        vm.prank(user1);
        farm.claimRewards();

        vm.prank(user2);
        farm.claimRewards();

        // Check that rewards are accruing correctly to both users
        uint256 earnedAUser1 = rewardTokenA.balanceOf(user1);
        uint256 earnedAUser2 = rewardTokenA.balanceOf(user2);

        // Both users have same stake, so should have similar rewards
        assertApproxEqAbs(earnedAUser1, earnedAUser2, 1e17, "Both users should have earned similar rewards");
    }

    function testOnlyOwnerFunctions() public {
        // User1 tries to add reward token
        vm.prank(user1);
        vm.expectRevert("DynamicRewardFarm: INVALID_OWNER");
        farm.addRewardToken(address(rewardTokenC));

        // User1 tries to set reward duration
        vm.prank(user1);
        vm.expectRevert("DynamicRewardFarm: INVALID_MANAGER");
        farm.setRewardDuration(60 days);
    }

    function testFarmWithdraw() public {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // Advance time
        vm.warp(block.timestamp + 50);

        // User1 withdraws tokens
        vm.prank(user1);
        farm.farmWithdraw(50e18);

        // Check balance
        uint256 stakeBalance = farm.balanceOf(user1);
        assertEq(stakeBalance, 50e18, "User1 should have 50 tokens staked");

        // Advance time
        vm.warp(block.timestamp + 50);

        // User1 claims rewards
        vm.prank(user1);
        farm.claimRewards();

        // Ensure rewards are received
        uint256 earnedA = rewardTokenA.balanceOf(user1);
        assertGt(earnedA, 0, "User1 should have earned rewards");
    }
}
