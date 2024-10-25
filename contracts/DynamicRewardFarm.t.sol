// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./DynamicRewardFarm.sol";
import "./TestToken.sol";

contract DynamicRewardFarmTest is Test {

    address constant DEAD_ADDRESS = address(
        0x000000000000000000000000000000000000dEaD
    );

    address constant ZERO_ADDRESS = address(
        0x0000000000000000000000000000000000000000
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

        // Initialize wrong duration
        vm.expectRevert("DynamicRewardFarm: INVALID_DURATION");
        farm.initialize(
            address(stakeToken),
            0,
            owner,
            owner,
            "Farm Receipt Token",
            "FARM"
        );

        farm.initialize(
            address(stakeToken),
            defaultDuration,
            owner,
            owner,
            "Farm Receipt Token",
            "FARM"
        );

        // should not be able to re-initialize
        vm.expectRevert("DynamicRewardFarm: ALREADY_INITIALIZED");
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
        assertApproxEqAbs(
            earnedAUser1,
            earnedAUser2,
            1e17,
            "Both users should have earned similar rewards"
        );
    }

    function testOnlyOwnerFunctions()
        public
    {
        // User1 tries to add reward token
        vm.prank(user1);

        vm.expectRevert(
            "DynamicRewardFarm: INVALID_OWNER"
        );

        farm.addRewardToken(
            address(rewardTokenC)
        );

        uint256 expectedTokens = 2;

        address[] memory rewardTokens = farm.getRewardTokens();
        assertEq(
            rewardTokens.length,
            expectedTokens,
            "Reward tokens should be 2"
        );

        // User1 tries to set reward duration
        vm.prank(user1);
        vm.expectRevert("DynamicRewardFarm: INVALID_MANAGER");
        farm.setRewardDuration(60 days);
    }

    function testOnlyOwnerCanAddRewardToken()
        public
    {
        // User1 tries to add reward token
        vm.prank(user2);
        vm.expectRevert("DynamicRewardFarm: INVALID_OWNER");
        farm.addRewardToken(
            address(rewardTokenC)
        );

        vm.prank(owner);
        farm.addRewardToken(
            address(rewardTokenC)
        );

        uint256 expectedTokens = 3;
        address[] memory rewardTokens = farm.getRewardTokens();

        assertEq(
            rewardTokens.length,
            expectedTokens,
            "Reward tokens should be 3"
        );

        assertEq(
            rewardTokens[2],
            address(rewardTokenC),
            "Reward token C should be the 3rd token"
        );
    }

    function testEarnedFunction() public {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100E18); // Stake 100 tokens

        // Fast forward time
        uint256 timeElapsed = 100;
        vm.warp(block.timestamp + timeElapsed);

        // Call earned(_walletAddress)
        uint256[] memory earnedRewards = farm.earned(user1);

        // There are two reward tokens, so earnedRewards should have length 2
        assertEq(earnedRewards.length, 2, "Should have earned rewards for 2 tokens");


        // Calculate expected rewards
         // reward rate per second * time

        // For each reward token, check the earned amount
        for (uint256 i = 0; i < earnedRewards.length; i++) {

            address rewardToken = farm.getRewardTokens()[i];

            uint256 earnedADead = farm.earnedByToken(
                address(rewardToken),
                DEAD_ADDRESS
            );

            uint256 expectedReward = defaultRewardRate
                * timeElapsed
                - earnedADead;

            assertApproxEqAbs(
                earnedRewards[i],
                expectedReward,
                1,
                "Earned rewards should match expected"
            );
        }
    }

    function testRewardPerToken()
        public
    {
        // Initially, rewardPerToken should be zero
        uint256 rewardPerTokenA = farm.rewardPerToken(
            address(rewardTokenA)
        );

        uint256 rewardPerTokenB = farm.rewardPerToken(
            address(rewardTokenB)
        );

        assertEq(
            rewardPerTokenA,
            0,
            "Initial rewardPerToken should be zero"
        );

        assertEq(
            rewardPerTokenB,
            0,
            "Initial rewardPerToken should be zero"
        );

        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18); // Stake 100 tokens

        // Fast forward time
        uint256 timeElapsed = 100;
        vm.warp(block.timestamp + timeElapsed);

        // Now check rewardPerToken
        rewardPerTokenA = farm.rewardPerToken(
            address(rewardTokenA)
        );

        rewardPerTokenB = farm.rewardPerToken(
            address(rewardTokenB)
        );

        // Expected rewardPerToken = (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime) * PRECISIONS) / totalStaked
        // Since lastUpdateTime was set when the user staked, so time frame is timeElapsed
        uint256 expectedRewardPerToken = defaultRewardRate
            * timeElapsed
            * PRECISIONS
            / 100e18; // Since totalStaked is 100e18

        assertApproxEqAbs(
            rewardPerTokenA,
            expectedRewardPerToken,
            1e17,
            "RewardPerToken should match expected"
        );

        assertApproxEqAbs(
            rewardPerTokenB,
            expectedRewardPerToken,
            1e17,
            "RewardPerToken should match expected"
        );
    }

    function testLastTimeRewardApplicable() public {
        uint256 periodFinished = farm.periodFinished();

        // Initially, lastTimeRewardApplicable() should be current timestamp
        uint256 lastApplicable = farm.lastTimeRewardApplicable();
        assertEq(lastApplicable, block.timestamp, "Last time reward applicable should be current time");

        // Fast forward time within the reward period
        uint256 timeElapsed = defaultDuration / 2;
        vm.warp(block.timestamp + timeElapsed);

        lastApplicable = farm.lastTimeRewardApplicable();
        assertEq(lastApplicable, block.timestamp, "Last time reward applicable should be current time");

        // Fast forward time beyond the reward period
        vm.warp(periodFinished + 100);

        lastApplicable = farm.lastTimeRewardApplicable();
        assertEq(lastApplicable, periodFinished, "Last time reward applicable should be period finished");
    }

    function testAddRewardTokenLimit()
        public
    {
        vm.startPrank(owner);

        // We have already added tokens A and B in setUp(), so we can add 8 more tokens (C to J)
        TestToken[] memory newTokens = new TestToken[](8);

        // Since 2 already exist, we can add 8 more
        uint256 remainingTokens = 8;

        for (uint256 i = 0; i < remainingTokens; i++) {
            newTokens[i] = new TestToken();
            newTokens[i].mintByMaster(1e27, owner); // Mint tokens to owner
            farm.addRewardToken(address(newTokens[i]));
        }

        // Now the total reward tokens should be 10

        // Try to add one more token (K), which should revert
        TestToken tokenK = new TestToken();
        tokenK.mintByMaster(1e27, owner); // Mint tokens to owner

        vm.expectRevert("DynamicRewardFarm: MAX_TOKENS_REACHED");
        farm.addRewardToken(address(tokenK));

        vm.stopPrank();

        // Verify that the number of reward tokens is indeed 10
        address[] memory rewardTokens = farm.getRewardTokens();
        assertEq(rewardTokens.length, 10, "Reward tokens should be 10");
    }

    function testAddRewardTokenDuplicate()
        public
    {
        // Owner tries to add reward token A again
        vm.prank(owner);
        vm.expectRevert(ExistingToken.selector);
        farm.addRewardToken(address(rewardTokenA));
    }

    function testExitFarm()
        public
    {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // Advance time
        vm.warp(block.timestamp + 50);

        // User1 exits farm
        vm.prank(user1);
        farm.exitFarm();

        // Check balances
        uint256 balanceUser1 = farm.balanceOf(user1);
        assertEq(
            balanceUser1,
            0,
            "User1 should have 0 tokens staked"
        );

        // Advance time
        vm.warp(block.timestamp + 50);

        // User1 claims rewards
        vm.prank(user1);

        uint256 earnedABefore = rewardTokenA.balanceOf(user1);
        farm.claimRewards();
        uint256 earnedAAfter = rewardTokenA.balanceOf(user1);

        assertEq(
            earnedABefore,
            earnedAAfter,
            "User1 should not have earned any rewards"
        );
    }

    function testInvalidOwner()
        public
    {
        // User1 tries to propose new owner
        vm.prank(user1);
        vm.expectRevert("DynamicRewardFarm: INVALID_OWNER");
        farm.proposeNewOwner(user2);
    }

    function testInvalidManager()
        public
    {
        // User1 tries to set reward duration
        vm.prank(user1);
        vm.expectRevert("DynamicRewardFarm: INVALID_MANAGER");
        farm.setRewardDuration(60 days);
    }

    // test invalid duration
    function testInvalidDuration()
        public
    {
        // Owner tries to set invalid duration
        vm.prank(owner);
        vm.expectRevert("DynamicRewardFarm: INVALID_DURATION");
        farm.setRewardDuration(0);
    }

    // test change duration during reward period
    function testChangeDurationDuringRewardPeriod()
        public
    {
        // Owner tries to set duration during reward period
        vm.prank(owner);
        vm.expectRevert("DynamicRewardFarm: ONGOING_DISTRIBUTION");
        farm.setRewardDuration(60 days);
    }

    // should not allow to set rewards without any tokens
    function testSetRewardRatesNoTokens()
        public
    {
        vm.warp(block.timestamp + defaultDuration);
        // Owner tries to set reward rates with no tokens
        address[] memory rewardTokens = new address[](3);
        uint256[] memory rewardRates = new uint256[](3);

        rewardTokens[0] = address(rewardTokenA);
        rewardTokens[1] = address(rewardTokenB);
        rewardTokens[2] = address(rewardTokenC);

        rewardRates[0] = 0;
        rewardRates[1] = 0;
        rewardRates[2] = 0;

        vm.startPrank(owner);

        farm.addRewardToken(
            address(rewardTokenC)
        );

        vm.expectRevert(NoRewards.selector);
        farm.setRewardRates(rewardTokens, rewardRates);
    }

    // allow to call changeManager only by owner
    function testChangeManager()
        public
    {
        // Owner changes manager
        vm.startPrank(owner);

        // try to set new manager to ZERO_ADDRESS
        vm.expectRevert(InvalidAddress.selector);
        farm.changeManager(ZERO_ADDRESS);

        farm.changeManager(user1);

        address newManager = farm.managerAddress();
        assertEq(
            newManager,
            user1,
            "Manager should be updated to user1"
        );

        vm.stopPrank();

        // if calling by non-owner should revert
        vm.prank(user1);
        vm.expectRevert("DynamicRewardFarm: INVALID_OWNER");
        farm.changeManager(user2);
    }

    function testRecoverRewardTokenFromDeadAddress()
        public
    {
        // Advance time so that DEAD_ADDRESS accumulates rewards
        vm.warp(block.timestamp + 1000);

        // Check how much rewards DEAD_ADDRESS has earned for rewardTokenA
        uint256 earnedByDeadA = farm.earnedByToken(
            address(rewardTokenA),
            DEAD_ADDRESS
        );

        uint256 earnedByDeadB = farm.earnedByToken(
            address(rewardTokenB),
            DEAD_ADDRESS
        );

        assertGt(
            earnedByDeadA,
            0,
            "DEAD_ADDRESS should have accumulated some RewardTokenA"
        );

        assertGt(
            earnedByDeadB,
            0,
            "DEAD_ADDRESS should have accumulated some RewardTokenB"
        );

        // Owner attempts to recover half of the rewards accumulated by DEAD_ADDRESS
        uint256 recoveryAmountA = earnedByDeadA / 2;
        uint256 recoveryAmountB = earnedByDeadB / 2;

        uint256 ownerBalanceBeforeA = rewardTokenA.balanceOf(owner);
        uint256 ownerBalanceBeforeB = rewardTokenB.balanceOf(owner);

        vm.startPrank(owner);

        farm.recoverToken(
            address(rewardTokenA),
            recoveryAmountA
        );

        farm.recoverToken(
            address(rewardTokenB),
            recoveryAmountB
        );

        vm.stopPrank();

        // Check that the owner's balance has increased by the recovery amounts
        uint256 ownerBalanceAfterA = rewardTokenA.balanceOf(owner);
        uint256 ownerBalanceAfterB = rewardTokenB.balanceOf(owner);

        assertEq(
            ownerBalanceAfterA - ownerBalanceBeforeA,
            recoveryAmountA,
            "Owner should have received recovered RewardTokenA"
        );

        assertEq(
            ownerBalanceAfterB - ownerBalanceBeforeB,
            recoveryAmountB,
            "Owner should have received recovered RewardTokenB"
        );

        // Check that the DEAD_ADDRESS's earned rewards have decreased by the recovery amounts
        uint256 newEarnedByDeadA = farm.earnedByToken(
            address(rewardTokenA),
            DEAD_ADDRESS
        );

        uint256 newEarnedByDeadB = farm.earnedByToken(
            address(rewardTokenB),
            DEAD_ADDRESS
        );

        assertEq(
            newEarnedByDeadA,
            earnedByDeadA - recoveryAmountA,
            "DEAD_ADDRESS's RewardTokenA rewards should have decreased"
        );

        assertEq(
            newEarnedByDeadB,
            earnedByDeadB - recoveryAmountB,
            "DEAD_ADDRESS's RewardTokenB rewards should have decreased"
        );

        vm.startPrank(owner);

        vm.expectRevert("DynamicRewardFarm: NOT_ENOUGH_REWARDS");
        farm.recoverToken(
            address(rewardTokenA),
            newEarnedByDeadA + 1 // excessiveRecoveryAmountA
        );

        vm.expectRevert("DynamicRewardFarm: NOT_ENOUGH_REWARDS");
        farm.recoverToken(
            address(rewardTokenB),
            newEarnedByDeadB + 1 // excessiveRecoveryAmountB
        );

        // try to withdraw remaining rewards
        farm.recoverToken(
            address(rewardTokenA),
            newEarnedByDeadA
        );

        farm.recoverToken(
            address(rewardTokenB),
            newEarnedByDeadB
        );

        // check that DEAD_ADDRESS has no more rewards
        uint256 newEarnedByDeadAAfter = farm.earnedByToken(
            address(rewardTokenA),
            DEAD_ADDRESS
        );

        uint256 newEarnedByDeadBAfter = farm.earnedByToken(
            address(rewardTokenB),
            DEAD_ADDRESS
        );

        assertEq(
            newEarnedByDeadAAfter,
            0,
            "DEAD_ADDRESS's RewardTokenA rewards should be zero"
        );

        assertEq(
            newEarnedByDeadBAfter,
            0,
            "DEAD_ADDRESS's RewardTokenB rewards should be zero"
        );

        // check that owner has all the rewards
        uint256 ownerBalanceAfterAAfter = rewardTokenA.balanceOf(owner);
        uint256 ownerBalanceAfterBAfter = rewardTokenB.balanceOf(owner);

        assertEq(
            ownerBalanceAfterAAfter - ownerBalanceBeforeA,
            recoveryAmountA + newEarnedByDeadA,
            "Owner should have received all RewardTokenA"
        );

        assertEq(
            ownerBalanceAfterBAfter - ownerBalanceBeforeB,
            recoveryAmountB + newEarnedByDeadB,
            "Owner should have received all RewardTokenB"
        );

        // try to withdraw again, should revert

        vm.expectRevert("DynamicRewardFarm: NOT_ENOUGH_REWARDS");
        farm.recoverToken(
            address(rewardTokenA),
            1
        );

        vm.expectRevert("DynamicRewardFarm: NOT_ENOUGH_REWARDS");
        farm.recoverToken(
            address(rewardTokenB),
            1
        );

        vm.stopPrank();
    }

    function testInvalidNewOwner()
        public
    {
        // Owner proposes new owner
        vm.prank(owner);
        farm.proposeNewOwner(DEAD_ADDRESS);

        // User1 claims ownership
        vm.prank(user1);
        vm.expectRevert("DynamicRewardFarm: INVALID_CANDIDATE");
        farm.claimOwnership();
    }

    function testNewOwnerWrongAddress()
        public
    {
        // Owner proposes new owner
        vm.prank(owner);
        vm.expectRevert(InvalidAddress.selector);
        farm.proposeNewOwner(ZERO_ADDRESS);
    }

    function testSetRewardRatesInvalidLength()
        public
    {
        // Owner tries to set reward rates with invalid length
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(rewardTokenA);
        rewardTokens[1] = address(rewardTokenB);

        uint256[] memory rewardRates = new uint256[](1);
        rewardRates[0] = defaultRewardRate;

        vm.startPrank(owner);

        vm.expectRevert("DynamicRewardFarm: ARRAY_LENGTH_MISMATCH");

        farm.setRewardRates(
            rewardTokens,
            rewardRates
        );

        address[] memory rewardTokens2 = new address[](3);
        rewardTokens2[0] = address(rewardTokenA);
        rewardTokens2[1] = address(rewardTokenB);
        rewardTokens2[2] = address(rewardTokenC);

        uint256[] memory rewardRates2 = new uint256[](3);
        rewardRates2[0] = defaultRewardRate;
        rewardRates2[1] = defaultRewardRate;
        rewardRates2[2] = defaultRewardRate;

        vm.expectRevert("DynamicRewardFarm: TOKEN_LENGTH_MISMATCH");
        farm.setRewardRates(
            rewardTokens2,
            rewardRates2
        );

        vm.stopPrank();
    }

    function testSetRewardRatesInvalidToken()
        public
    {
        // Owner tries to set reward rates with invalid token
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(rewardTokenA);
        rewardTokens[1] = DEAD_ADDRESS;

        uint256[] memory rewardRates = new uint256[](2);
        rewardRates[0] = defaultRewardRate;
        rewardRates[1] = defaultRewardRate;

        address currentManager = farm.managerAddress();

        vm.startPrank(owner);
        // transfer reward tokens to manager
        rewardTokenA.transfer(currentManager, 1e27);
        rewardTokenB.transfer(currentManager, 1e27);

        vm.stopPrank();
        vm.startPrank(currentManager);

        // approve tokens
        rewardTokenA.approve(address(farm), type(uint256).max);
        rewardTokenB.approve(address(farm), type(uint256).max);

        vm.expectRevert("DynamicRewardFarm: INVALID_TOKEN_ORDER");

        farm.setRewardRates(
            rewardTokens,
            rewardRates
        );

        vm.stopPrank();
    }

    function testSetRewardRatesInvalidRate()
        public
    {
        // Owner tries to set reward rates with invalid rate
        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(rewardTokenA);
        rewardTokens[1] = address(rewardTokenB);

        uint256[] memory rewardRates = new uint256[](2);
        rewardRates[0] = defaultRewardRate;
        rewardRates[1] = 0;

        vm.prank(owner);

        vm.expectRevert("DynamicRewardFarm: RATE_CANT_DECREASE");

        farm.setRewardRates(
            rewardTokens,
            rewardRates
        );
    }

    function testAddTokenZeroAddress()
        public
    {
        // Owner tries to add token with zero address
        vm.prank(owner);
        vm.expectRevert(InvalidAddress.selector);
        farm.addRewardToken(ZERO_ADDRESS);
    }

    function testClaimOwnership()
        public
    {
        // Owner proposes new owner
        vm.prank(owner);
        farm.proposeNewOwner(user1);

        // User1 claims ownership
        vm.prank(user1);
        farm.claimOwnership();

        address newOwner = farm.ownerAddress();
        assertEq(
            newOwner,
            user1,
            "Owner should be updated to user1"
        );
    }

    function testFarmWithdraw()
        public
    {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // Advance time
        vm.warp(block.timestamp + 50);

        uint256 withdrawAmout = 50E18;

        // User1 withdraws tokens
        vm.prank(user1);

        farm.farmWithdraw(
            withdrawAmout
        );

        // Check balance
        uint256 stakeBalance = farm.balanceOf(
            user1
        );

        assertEq(
            stakeBalance,
            withdrawAmout,
            "User1 should have 50 tokens staked"
        );

        // Advance time
        vm.warp(block.timestamp + 50);

        // User1 claims rewards
        vm.prank(user1);
        farm.claimRewards();

        // Ensure rewards are received
        uint256 earnedA = rewardTokenA.balanceOf(
            user1
        );

        assertGt(
            earnedA,
            0,
            "User1 should have earned rewards"
        );
    }

    // Test transferFrom function
    function testTransferFrom()
        public
    {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        uint256 expectedTokens = 50E18;

        // User1 approves farm to spend tokens
        vm.prank(user1);
        farm.approve(
            user1,
            expectedTokens
        );

        // User1 transfers tokens to User2
        vm.prank(user1);
        farm.transferFrom(
            user1,
            user2,
            expectedTokens
        );

        // Check balances
        uint256 balanceUser1 = farm.balanceOf(
            user1
        );

        uint256 balanceUser2 = farm.balanceOf(
            user2
        );

        assertEq(
            balanceUser1,
            expectedTokens,
            "User1 should have 50 tokens staked"
        );

        assertEq(
            balanceUser2,
            expectedTokens,
            "User2 should have 50 tokens staked"
        );

        // Advance time
        vm.warp(block.timestamp + 100);

        // Both users claim rewards
        vm.prank(user1);
        farm.claimRewards();

        vm.prank(user2);
        farm.claimRewards();

        // Check rewards
        uint256 earnedAUser1 = rewardTokenA.balanceOf(
            user1
        );

        uint256 earnedAUser2 = rewardTokenA.balanceOf(
            user2
        );

        // Both users have same stake, so should have similar rewards
        assertApproxEqAbs(
            earnedAUser1,
            earnedAUser2,
            1e17,
            "Both users should have earned similar rewards"
        );
    }

    // Test transfer function
    function testTransfer()
        public
    {
        // User1 stakes tokens
        vm.prank(user1);
        farm.farmDeposit(100e18);

        // User1 transfers tokens to User2
        vm.prank(user1);
        farm.transfer(
            user2,
            50e18
        );

        // Check balances
        uint256 balanceUser1 = farm.balanceOf(
            user1
        );

        uint256 balanceUser2 = farm.balanceOf(
            user2
        );

        assertEq(
            balanceUser1,
            50e18,
            "User1 should have 50 tokens staked"
        );

        assertEq(
            balanceUser2,
            50e18,
            "User2 should have 50 tokens staked"
        );

        // Advance time
        vm.warp(block.timestamp + 100);

        // Both users claim rewards
        vm.prank(user1);
        farm.claimRewards();

        vm.prank(user2);
        farm.claimRewards();

        // Check rewards
        uint256 earnedAUser1 = rewardTokenA.balanceOf(
            user1
        );

        uint256 earnedAUser2 = rewardTokenA.balanceOf(
            user2
        );

        // Both users have same stake, so should have similar rewards
        assertApproxEqAbs(
            earnedAUser1,
            earnedAUser2,
            1e17,
            "Both users should have earned similar rewards"
        );
    }
}
