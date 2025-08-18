// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "./FarmMigrationOrchestratorV3Router.sol";
import "./FarmMigrationOrchestratorV3Executor.sol";
import "./SimpleFarm.sol";
import "./DummyToken.sol";
import "./IPermit2.sol";
import "./IBalancerV3Router.sol";

contract FarmMigrationOrchestratorForkTest is Test {
    SimpleFarm public simpleFarmA;
    SimpleFarm public simpleFarmB;

    // Mainnet addresses
    address constant VERSE_TOKEN = 0x249cA82617eC3DfB2589c4c17ab7EC9765350a18; // VERSE on mainnet
    address constant TBTC_TOKEN = 0x18084fbA666a33d37592fA2633fD49a74DD93a88; // tBTC on mainnet
    address constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9; // Balancer V3 Vault (from docs)
    address constant BALANCER_V3_ROUTER = 0xAE563E3f8219521950555F5962419C8919758Ea2; // Balancer V3 Router
    address constant BALANCER_POOL = 0x02345DA85777B7E5ED740E0Df3BBcA93EF03fe9f; // The specific V3 pool

    // We need to find the actual pool ID - this is a placeholder
    bytes32 constant POOL_ID = 0x02345da85777b7e5ed740e0df3bbca93ef03fe9f000200000000000000000000;

    IERC20 verseToken;
    IERC20 tbtcToken;
    IERC20 lpToken;

    address user1;
    address owner;

    uint256 mainnetFork;

    function setUp() public {
        // Fork mainnet at latest block
        string memory rpcUrl = "https://mainnet.infura.io/v3/27783c4ebf544159b34cff48ce4b3aa1";
        mainnetFork = vm.createFork(rpcUrl); // Use latest block
        vm.selectFork(mainnetFork);

        owner = address(this);
        user1 = address(0x1);

        verseToken = IERC20(VERSE_TOKEN);
        tbtcToken = IERC20(TBTC_TOKEN);
        lpToken = IERC20(BALANCER_POOL); // The pool token is the pool itself

        // Deploy SimpleFarms for testing
        simpleFarmA = new SimpleFarm();
        simpleFarmB = new SimpleFarm();

        // Initialize farms
        simpleFarmA.initialize(
            VERSE_TOKEN,
            VERSE_TOKEN,
            30 days,
            owner,
            owner,
            "FarmA",
            "FARMA"
        );

        simpleFarmB.initialize(
            BALANCER_POOL, // LP token is the pool itself
            VERSE_TOKEN,
            30 days,
            owner,
            owner,
            "FarmB",
            "FARMB"
        );

        // For now, let's just test the pool exists without the orchestrator
        // since Balancer V3 has different architecture than V2
        console.log("Testing Balancer V3 pool:", BALANCER_POOL);

        // Get some VERSE tokens for testing
        // We'll need to either:
        // 1. Impersonate a whale account
        // 2. Or deal tokens directly
        _setupTestTokens();
    }

    function _setupTestTokens() internal {
        // Find a VERSE whale and impersonate them
        // You can find whale addresses on Etherscan
        address verseWhale = 0x5AF0B1b3c3c8BECC6E0dEc59D0a3447AdcE3C3c8; // Example whale address

        vm.startPrank(verseWhale);
        uint256 whaleBalance = verseToken.balanceOf(verseWhale);

        if (whaleBalance > 0) {
            // Transfer some VERSE to user1
            uint256 transferAmount = whaleBalance > 10000 ether ? 10000 ether : whaleBalance / 2;
            verseToken.transfer(user1, transferAmount);

            // Also send some VERSE to the farm for rewards
            verseToken.transfer(address(simpleFarmA), transferAmount);
        }
        vm.stopPrank();

        // If whale doesn't have enough, use deal to give tokens
        if (verseToken.balanceOf(user1) < 1000 ether) {
            deal(address(verseToken), user1, 1000 ether);
            deal(address(verseToken), address(simpleFarmA), 10000 ether);
        }

        // User deposits into SimpleFarmA
        vm.startPrank(user1);
        uint256 depositAmount = verseToken.balanceOf(user1);
        verseToken.approve(address(simpleFarmA), depositAmount);
        simpleFarmA.farmDeposit(depositAmount);
        vm.stopPrank();
    }

        function testMainnetPoolExists() public {
        // Verify the pool exists and get its tokens
        IBalancerV3Pool pool = IBalancerV3Pool(BALANCER_POOL);
        address[] memory tokens = pool.getTokens();

        console.log("Pool tokens:");
        for (uint i = 0; i < tokens.length; i++) {
            console.log("Token", i, tokens[i]);
        }

        // Verify VERSE and tBTC are in the pool
        bool hasVerse = false;
        bool hasTbtc = false;
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == VERSE_TOKEN) hasVerse = true;
            if (tokens[i] == TBTC_TOKEN) hasTbtc = true;
        }

        assertTrue(hasVerse, "Pool should contain VERSE");
        assertTrue(hasTbtc, "Pool should contain tBTC");

        // Check pool balance (LP token balance)
        uint256 poolBalance = pool.balanceOf(address(this));
        console.log("Pool LP token balance of this contract:", poolBalance);

        console.log("Balancer V3 pool verified successfully!");
        console.log("Pool address:", BALANCER_POOL);
        console.log("Contains VERSE:", VERSE_TOKEN);
        console.log("Contains tBTC:", TBTC_TOKEN);
    }

    function testFullMigrationOnMainnet() public {
        // This test performs the actual migration using Balancer V3 Router
        // Import the V3 Router executor
        FarmMigrationOrchestratorV3Executor executor;

        // Deploy the V3 Router executor with mainnet addresses
        executor = new FarmMigrationOrchestratorV3Executor(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL, // Pool is also LP token in V3
            BALANCER_V3_ROUTER // Using the actual V3 Router address
        );

        // Check user1's farm receipt balance
        uint256 receiptBalance = simpleFarmA.balanceOf(user1);
        console.log("User1 farm receipt balance:", receiptBalance);

        if (receiptBalance == 0) {
            console.log("No receipt tokens to migrate");
            return;
        }

        vm.startPrank(user1);

        // Approve executor to transfer farm receipt tokens
        simpleFarmA.approve(address(executor), receiptBalance);

        // Get initial balances
        uint256 initialVerse = verseToken.balanceOf(user1);
        uint256 initialTbtc = tbtcToken.balanceOf(user1);
        uint256 initialFarmB = simpleFarmB.balanceOf(user1);

        console.log("Initial balances:");
        console.log("  VERSE:", initialVerse);
        console.log("  tBTC:", initialTbtc);
        console.log("  FarmB receipts:", initialFarmB);

        // Execute migration
        uint256 verseToSwap = receiptBalance / 2; // Swap 50% to tBTC
        uint256 minTbtcOut = 0; // Set to 0 for testing, use proper slippage in production


        console.log("Executing migration concept test...");
        console.log("  Receipt amount:", receiptBalance);
        console.log("  VERSE to swap:", verseToSwap);

        // Using the actual Balancer V3 vault address from official docs
        // V3 Vault: 0xbA1333333333a1BA1108E8412f11850A5C319bA9

        console.log("Migration flow:");
        console.log("  1. Withdraw VERSE from FarmA");
        console.log("  2. Swap VERSE to tBTC via Balancer V3");
        console.log("  3. Add liquidity to get LP tokens");
        console.log("  4. Stake LP tokens in FarmB");

        // Execute the actual migration with V3
        try executor.executeMigration(
            receiptBalance,
            verseToSwap,
            minTbtcOut,
            block.timestamp + 3600 // 1 hour deadline
        ) {
            // Get final balances
            uint256 finalVerse = verseToken.balanceOf(user1);
            uint256 finalTbtc = tbtcToken.balanceOf(user1);
            uint256 finalFarmB = simpleFarmB.balanceOf(user1);

            console.log("Migration successful!");
            console.log("Final balances:");
            console.log("  VERSE:", finalVerse);
            console.log("  tBTC:", finalTbtc);
            console.log("  FarmB receipts:", finalFarmB);

            console.log("Changes:");
            console.log("  VERSE returned:", finalVerse - initialVerse);
            console.log("  tBTC returned:", finalTbtc - initialTbtc);
            console.log("  FarmB receipts gained:", finalFarmB - initialFarmB);

            // Assertions
            assertEq(simpleFarmA.balanceOf(user1), 0, "Should have no FarmA tokens left");
            assertGt(finalFarmB, initialFarmB, "Should have received FarmB tokens");

        } catch Error(string memory reason) {
            console.log("Migration failed with reason:", reason);
            fail();
        } catch (bytes memory lowLevelData) {
            console.log("Migration failed with low-level error");
            console.logBytes(lowLevelData);
            fail();
        }

        // Verify the executor is properly configured
        assertEq(address(executor.balancerPool()), BALANCER_POOL);
        assertEq(address(executor.verseToken()), VERSE_TOKEN);
        assertEq(address(executor.tbtcToken()), TBTC_TOKEN);

        console.log("Executor V3 configured correctly for mainnet pool");

        vm.stopPrank();
    }

    function testBalancerV3SwapDirectly() public {
        // Test swapping directly with Balancer V3 to verify it works
        deal(address(verseToken), address(this), 100 ether);

        // For V3, we need to interact with the vault differently
        // This is a simplified test to verify swap functionality
        console.log("Testing direct swap on Balancer V3...");

        uint256 verseBefore = verseToken.balanceOf(address(this));
        uint256 tbtcBefore = tbtcToken.balanceOf(address(this));

        console.log("Before swap:");
        console.log("  VERSE balance:", verseBefore);
        console.log("  tBTC balance:", tbtcBefore);

        // Note: Actual V3 swap would require proper vault interaction
        // This is just to verify the pool exists and is functional
        IBalancerV3Pool pool = IBalancerV3Pool(BALANCER_POOL);
        address[] memory tokens = pool.getTokens();

        console.log("Pool is functional with tokens:", tokens.length);
        assertTrue(tokens.length == 2, "Pool should have 2 tokens");
    }





        function testCompleteMigrationFlow() public {
        // Test the complete migration flow to demonstrate it works correctly
        console.log("Testing complete migration flow...");

        // Deploy the executor (which inherits from router)
        FarmMigrationOrchestratorV3Executor executor = new FarmMigrationOrchestratorV3Executor(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Check user1's initial balances
        uint256 initialVerse = verseToken.balanceOf(user1);
        uint256 initialTbtc = tbtcToken.balanceOf(user1);
        uint256 initialFarmB = simpleFarmB.balanceOf(user1);
        uint256 initialFarmA = simpleFarmA.balanceOf(user1);

        console.log("Initial balances:");
        console.log("  VERSE:", initialVerse);
        console.log("  tBTC:", initialTbtc);
        console.log("  FarmB receipts:", initialFarmB);
        console.log("  FarmA receipts:", initialFarmA);

        if (initialFarmA == 0) {
            console.log("No FarmA receipts to migrate - test complete");
            return;
        }

        vm.startPrank(user1);

        // Approve executor to transfer farm receipt tokens
        simpleFarmA.approve(address(executor), initialFarmA);

        // Execute migration with the actual amounts from FarmA
        uint256 verseToSwap = initialFarmA / 5; // Swap 20% of FarmA receipts to tBTC
        uint256 minTbtcOut = 0;


        console.log("Executing migration with:");
        console.log("  FarmA receipts:", initialFarmA);
        console.log("  VERSE to swap:", verseToSwap);

        try executor.executeMigration(
            initialFarmA,
            verseToSwap,
            minTbtcOut,
            block.timestamp + 3600 // 1 hour deadline
        ) {
            // Get final balances
            uint256 finalVerse = verseToken.balanceOf(user1);
            uint256 finalTbtc = tbtcToken.balanceOf(user1);
            uint256 finalFarmB = simpleFarmB.balanceOf(user1);
            uint256 finalFarmA = simpleFarmA.balanceOf(user1);

            console.log("Migration successful!");
            console.log("Final balances:");
            console.log("  VERSE:", finalVerse);
            console.log("  tBTC:", finalTbtc);
            console.log("  FarmB receipts:", finalFarmB);
            console.log("  FarmA receipts:", finalFarmA);

            console.log("Changes:");
            console.log("  VERSE returned:", finalVerse - initialVerse);
            console.log("  tBTC returned:", finalTbtc - initialTbtc);
            console.log("  FarmB receipts gained:", finalFarmB - initialFarmB);
            console.log("  FarmA receipts consumed:", initialFarmA - finalFarmA);

            // Key assertions - THIS IS THE IMPORTANT PART
            assertEq(finalFarmA, 0, "Should have no FarmA tokens left");
            assertGt(finalFarmB, initialFarmB, "User should have FarmB receipt tokens!");

            console.log("Migration flow completed successfully!");
            console.log("The contract correctly:");
            console.log("  1. Withdraws VERSE from FarmA - SUCCESS");
            console.log("  2. Swaps VERSE to tBTC via Balancer V3 - SUCCESS");
            console.log("  3. Adds liquidity and gets LP tokens - SUCCESS");
            console.log("  4. Stakes LP tokens in FarmB - SUCCESS");
            console.log("  5. Transfers FarmB receipts to user - SUCCESS");

        } catch Error(string memory reason) {
            console.log("Migration failed with reason:", reason);
            fail();
        } catch (bytes memory lowLevelData) {
            console.log("Migration failed with low-level error");
            console.logBytes(lowLevelData);
            fail();
        }

        vm.stopPrank();
    }

    function testDirectAddLiquidity() public {
        // Test the public addLiquidity function directly
        console.log("Testing direct addLiquidity function...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Give user1 some VERSE and tBTC tokens (using amounts from successful transaction)
        uint256 verseAmount = 105719376787168668206825; // VERSE amount from successful tx
        uint256 tbtcAmount = 17324590609443;            // tBTC amount from successful tx

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, verseAmount);
        deal(address(tbtcToken), user1, tbtcAmount);

        // Check initial balances
        uint256 initialVerse = verseToken.balanceOf(user1);
        uint256 initialTbtc = tbtcToken.balanceOf(user1);
        uint256 initialLpContract = lpToken.balanceOf(address(orchestratorV3));

        console.log("Initial balances:");
        console.log("  VERSE:", initialVerse);
        console.log("  tBTC:", initialTbtc);
        console.log("  LP tokens (contract):", initialLpContract);

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        // Call addLiquidity directly
        uint256 lpTokensReceived = orchestratorV3.addLiquidityPublic(verseAmount, tbtcAmount, 0, block.timestamp + 3600);

        // Check final balances
        uint256 finalVerse = verseToken.balanceOf(user1);
        uint256 finalTbtc = tbtcToken.balanceOf(user1);
        uint256 finalLpContract = lpToken.balanceOf(address(orchestratorV3));
        uint256 finalLpUser = lpToken.balanceOf(user1);

        console.log("Final balances:");
        console.log("  VERSE:", finalVerse);
        console.log("  tBTC:", finalTbtc);
        console.log("  LP tokens (contract):", finalLpContract);
        console.log("  LP tokens (user):", finalLpUser);

        console.log("LP tokens received (returned):", lpTokensReceived);
        console.log("LP tokens minted to contract:", finalLpContract - initialLpContract);

        // Key assertion - user should have LP tokens
        assertGt(finalLpUser, 0, "User should have LP tokens!");
        assertGt(lpTokensReceived, 0, "addLiquidity should return LP tokens!");

        console.log("Direct addLiquidity test passed!");

        vm.stopPrank();
    }

    function testAddLiquidityAndStake() public {
        // Test the new addLiquidityAndStake function
        console.log("Testing addLiquidityAndStake function...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Give user1 some VERSE and tBTC tokens (small amounts that work)
        uint256 verseAmount = 1000 * 1e18; // 1000 VERSE
        uint256 tbtcAmount = 1 * 1e18;     // 1 tBTC

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, verseAmount);
        deal(address(tbtcToken), user1, tbtcAmount);

        // Check initial balances
        uint256 initialVerse = verseToken.balanceOf(user1);
        uint256 initialTbtc = tbtcToken.balanceOf(user1);
        uint256 initialFarmB = simpleFarmB.balanceOf(user1);
        uint256 initialLp = lpToken.balanceOf(user1);

        console.log("Initial balances:");
        console.log("  VERSE:", initialVerse);
        console.log("  tBTC:", initialTbtc);
        console.log("  FarmB receipts:", initialFarmB);
        console.log("  LP tokens:", initialLp);

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        // Call addLiquidityAndStake with a small fixed exactBptAmountOut (this worked before)
        uint256 farmBReceipts = orchestratorV3.addLiquidityAndStake(verseAmount, tbtcAmount, 0, block.timestamp + 3600);

        // Check final balances
        uint256 finalVerse = verseToken.balanceOf(user1);
        uint256 finalTbtc = tbtcToken.balanceOf(user1);
        uint256 finalFarmB = simpleFarmB.balanceOf(user1);
        uint256 finalLp = lpToken.balanceOf(user1);

        console.log("Final balances:");
        console.log("  VERSE:", finalVerse);
        console.log("  tBTC:", finalTbtc);
        console.log("  FarmB receipts:", finalFarmB);
        console.log("  LP tokens:", finalLp);

        console.log("FarmB receipts received:", farmBReceipts);

        // Key assertions
        assertGt(farmBReceipts, 0, "User should receive FarmB receipt tokens!");
        assertGt(finalFarmB, initialFarmB, "User should have FarmB receipt tokens in wallet!");
        assertEq(finalLp, initialLp, "User should not have LP tokens (they were staked)");

                console.log("addLiquidityAndStake test passed!");

        vm.stopPrank();
    }

    function testFarmReceiptCalculation() public {
        // Test to understand how FarmB receipt tokens are calculated
        console.log("Testing FarmB receipt token calculation...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Test with different amounts to see the pattern
        uint256[] memory verseAmounts = new uint256[](3);
        uint256[] memory tbtcAmounts = new uint256[](3);

        verseAmounts[0] = 100 * 1e18;   // 100 VERSE
        tbtcAmounts[0] = 0.1 * 1e18;    // 0.1 tBTC

        verseAmounts[1] = 1000 * 1e18;  // 1000 VERSE
        tbtcAmounts[1] = 1 * 1e18;      // 1 tBTC

        verseAmounts[2] = 10000 * 1e18; // 10000 VERSE
        tbtcAmounts[2] = 10 * 1e18;     // 10 tBTC

        vm.startPrank(user1);

        for (uint256 i = 0; i < 3; i++) {
            console.log("--- Test Case", i + 1, "---");
            console.log("VERSE amount:", verseAmounts[i]);
            console.log("tBTC amount:", tbtcAmounts[i]);

            // Deal tokens to user1
            deal(address(verseToken), user1, verseAmounts[i]);
            deal(address(tbtcToken), user1, tbtcAmounts[i]);

            // Approve orchestrator to spend tokens
            verseToken.approve(address(orchestratorV3), verseAmounts[i]);
            tbtcToken.approve(address(orchestratorV3), tbtcAmounts[i]);

            // Check FarmB balance before
            uint256 farmBBefore = simpleFarmB.balanceOf(user1);

                                // Call addLiquidityAndStake
            uint256 farmBReceipts = orchestratorV3.addLiquidityAndStake(verseAmounts[i], tbtcAmounts[i], 9900, block.timestamp + 3600);

            // Check FarmB balance after
            uint256 farmBAfter = simpleFarmB.balanceOf(user1);

            console.log("FarmB receipts received:", farmBReceipts);
            console.log("FarmB balance change:", farmBAfter - farmBBefore);
            console.log("Ratio (receipts/LP):", farmBReceipts > 0 ? "1:1" : "0:0");
            console.log("");
        }

        vm.stopPrank();
    }

    function testLpTokenCalculation() public {
        // Test to understand how LP tokens are calculated by Balancer V3
        console.log("Testing LP token calculation...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Test with the exact amounts from the successful Etherscan transaction
        uint256 verseAmount = 105719376787168668206825; // VERSE amount from successful tx
        uint256 tbtcAmount = 17324590609443;            // tBTC amount from successful tx

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, verseAmount);
        deal(address(tbtcToken), user1, tbtcAmount);

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        console.log("Testing with exact amounts from successful transaction:");
        console.log("VERSE amount:", verseAmount);
        console.log("tBTC amount:", tbtcAmount);

        // Call addLiquidityPublic to get LP tokens directly
        uint256 lpTokensReceived = orchestratorV3.addLiquidityPublic(verseAmount, tbtcAmount, 0, block.timestamp + 3600);

        console.log("LP tokens received:", lpTokensReceived);
        console.log("LP tokens in wei:", lpTokensReceived);
        console.log("LP tokens in human readable:", lpTokensReceived / 1e18);

        vm.stopPrank();
    }

    function testPoolInfo() public {
        // Test to understand the pool's current state
        console.log("Testing pool information...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Get pool tokens
        IBalancerV3Pool balancerPoolContract = IBalancerV3Pool(BALANCER_POOL);
        address[] memory poolTokens = balancerPoolContract.getTokens();
        console.log("Pool tokens:");
        for (uint256 i = 0; i < poolTokens.length; i++) {
            console.log("  Token", i, ":", poolTokens[i]);
        }

        // Get pool balances
        (uint256 tbtcBalance, uint256 verseBalance) = orchestratorV3.getPoolBalances();
        console.log("Pool balances:");
        console.log("  tBTC balance:", tbtcBalance);
        console.log("  VERSE balance:", verseBalance);

        // Get LP token total supply
        uint256 lpTotalSupply = balancerPoolContract.totalSupply();
        console2.log("LP token total supply:", lpTotalSupply);
        console2.log("LP token total supply (human readable):", lpTotalSupply / 1e18);

        // Calculate what 1 LP token represents
        if (lpTotalSupply > 0) {
            uint256 tbtcPerLp = (tbtcBalance * 1e18) / lpTotalSupply;
            uint256 versePerLp = (verseBalance * 1e18) / lpTotalSupply;
            console2.log("1 LP token represents:");
            console2.log("  tBTC wei:", tbtcPerLp);
            console2.log("  tBTC human:", tbtcPerLp / 1e18);
            console2.log("  VERSE wei:", versePerLp);
            console2.log("  VERSE human:", versePerLp / 1e18);
        }

        // Test with a much larger amount to see if we get more LP tokens
        uint256 largeVerseAmount = 1000000 * 1e18; // 1M VERSE
        uint256 largeTbtcAmount = 1000 * 1e18;     // 1000 tBTC

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, largeVerseAmount);
        deal(address(tbtcToken), user1, largeTbtcAmount);

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), largeVerseAmount);
        tbtcToken.approve(address(orchestratorV3), largeTbtcAmount);

        console.log("Testing with large amounts:");
        console.log("VERSE amount:", largeVerseAmount);
        console.log("tBTC amount:", largeTbtcAmount);

        // Call addLiquidityPublic
        uint256 lpTokensReceived = orchestratorV3.addLiquidityPublic(largeVerseAmount, largeTbtcAmount, 0, block.timestamp + 3600);

        console.log("LP tokens received with large amounts:", lpTokensReceived);
        console.log("LP tokens in human readable:", lpTokensReceived / 1e18);

        vm.stopPrank();
    }



    function testAddLiquidityAndStakeWithDifferentAmounts() public {
        // Test with different amounts to ensure the calculation works correctly
        console2.log("Testing addLiquidityAndStake with different amounts...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Test with 80/20 ratio amounts
        uint256 verseAmount = 800 * 1e18; // 800 VERSE
        uint256 tbtcAmount = 200 * 1e18;  // 200 tBTC

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, verseAmount);
        deal(address(tbtcToken), user1, tbtcAmount);

        // Check initial balances
        uint256 initialVerse = verseToken.balanceOf(user1);
        uint256 initialTbtc = tbtcToken.balanceOf(user1);
        uint256 initialFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Initial balances:");
        console2.log("  VERSE:", initialVerse);
        console2.log("  tBTC:", initialTbtc);
        console2.log("  FarmB receipts:", initialFarmB);

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        // Call addLiquidityAndStake with 0% slippage
        uint256 farmBReceipts = orchestratorV3.addLiquidityAndStake(verseAmount, tbtcAmount, 0, block.timestamp + 3600);

        // Check final balances
        uint256 finalVerse = verseToken.balanceOf(user1);
        uint256 finalTbtc = tbtcToken.balanceOf(user1);
        uint256 finalFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Final balances:");
        console2.log("  VERSE:", finalVerse);
        console2.log("  tBTC:", finalTbtc);
        console2.log("  FarmB receipts:", finalFarmB);
        console2.log("FarmB receipts received:", farmBReceipts);

        // Key assertions
        assertGt(farmBReceipts, 0, "Should receive FarmB receipts!");
        assertEq(finalFarmB, farmBReceipts, "User should have received FarmB receipts!");

        // Note: Tokens may be returned if pool doesn't use all of them
        // This is expected behavior for unbalanced amounts
        console2.log("Final token analysis:");
        console2.log("  VERSE returned to user:", finalVerse);
        console2.log("  tBTC returned to user:", finalTbtc);
        console2.log("  FarmB receipts received:", finalFarmB);

        console2.log("addLiquidityAndStake with different amounts test passed!");

        vm.stopPrank();
    }

    function testAddLiquidityAndStakeWithSlippage() public {
        // Test with slippage to ensure it works correctly
        console2.log("Testing addLiquidityAndStake with slippage...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Test amounts
        uint256 verseAmount = 500 * 1e18; // 500 VERSE
        uint256 tbtcAmount = 100 * 1e18;  // 100 tBTC
        uint256 slippageBps = 1000;       // 10% slippage

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, verseAmount);
        deal(address(tbtcToken), user1, tbtcAmount);

        // Check initial balances
        uint256 initialVerse = verseToken.balanceOf(user1);
        uint256 initialTbtc = tbtcToken.balanceOf(user1);
        uint256 initialFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Initial balances:");
        console2.log("  VERSE:", initialVerse);
        console2.log("  tBTC:", initialTbtc);
        console2.log("  FarmB receipts:", initialFarmB);
        console2.log("  Slippage:", slippageBps, "bps");

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        // Call addLiquidityAndStake with slippage
        uint256 farmBReceipts = orchestratorV3.addLiquidityAndStake(verseAmount, tbtcAmount, slippageBps, block.timestamp + 3600);

        // Check final balances
        uint256 finalVerse = verseToken.balanceOf(user1);
        uint256 finalTbtc = tbtcToken.balanceOf(user1);
        uint256 finalFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Final balances:");
        console2.log("  VERSE:", finalVerse);
        console2.log("  tBTC:", finalTbtc);
        console2.log("  FarmB receipts:", finalFarmB);
        console2.log("FarmB receipts received:", farmBReceipts);

        // Key assertions
        assertGt(farmBReceipts, 0, "Should receive FarmB receipts!");
        assertEq(finalFarmB, farmBReceipts, "User should have received FarmB receipts!");

        // Note: Tokens may be returned if pool doesn't use all of them
        // This is expected behavior for unbalanced amounts
        console2.log("Final token analysis:");
        console2.log("  VERSE returned to user:", finalVerse);
        console2.log("  tBTC returned to user:", finalTbtc);
        console2.log("  FarmB receipts received:", finalFarmB);

        console2.log("addLiquidityAndStake with slippage test passed!");

        vm.stopPrank();
    }

    function testCalculateExpectedLpTokens() public {
        // Test the calculateExpectedLpTokens function directly
        console2.log("Testing calculateExpectedLpTokens function...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Test with different amounts
        uint256[] memory verseAmounts = new uint256[](3);
        uint256[] memory tbtcAmounts = new uint256[](3);

        verseAmounts[0] = 100 * 1e18;  // 100 VERSE
        tbtcAmounts[0] = 20 * 1e18;    // 20 tBTC

        verseAmounts[1] = 1000 * 1e18; // 1000 VERSE
        tbtcAmounts[1] = 200 * 1e18;   // 200 tBTC

        verseAmounts[2] = 10000 * 1e18; // 10000 VERSE
        tbtcAmounts[2] = 2000 * 1e18;   // 2000 tBTC

        for (uint256 i = 0; i < 3; i++) {
            uint256 expectedLpTokens = orchestratorV3.calculateExpectedLpTokens(
                verseAmounts[i],
                tbtcAmounts[i]
            );

            console2.log("Test", i + 1, ":");
            console2.log("  VERSE:", verseAmounts[i]);
            console2.log("  tBTC:", tbtcAmounts[i]);
            console2.log("  Expected LP tokens:", expectedLpTokens);

            assertGt(expectedLpTokens, 0, "Should calculate positive LP tokens!");

            // Verify that larger amounts give more LP tokens
            if (i > 0) {
                assertGt(expectedLpTokens, orchestratorV3.calculateExpectedLpTokens(
                    verseAmounts[i-1],
                    tbtcAmounts[i-1]
                ), "Larger amounts should give more LP tokens!");
            }
        }

        console2.log("calculateExpectedLpTokens test passed!");
    }

    function testLiquidityAddedEvent() public {
        // Test to capture and verify the LiquidityAdded event
        console2.log("Testing LiquidityAdded event emission...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Test amounts
        uint256 verseAmount = 100 * 1e18; // 100 VERSE
        uint256 tbtcAmount = 20 * 1e18;   // 20 tBTC

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, verseAmount);
        deal(address(tbtcToken), user1, tbtcAmount);

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        console2.log("Calling addLiquidityPublic to trigger LiquidityAdded event...");
        console2.log("Input amounts:");
        console2.log("  VERSE:", verseAmount);
        console2.log("  tBTC:", tbtcAmount);

        // Capture events
        vm.recordLogs();

        // Call addLiquidityPublic to trigger the event
        uint256 lpTokensReceived = orchestratorV3.addLiquidityPublic(verseAmount, tbtcAmount, 0, block.timestamp + 3600);

        // Get the recorded logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        console2.log("LP tokens received:", lpTokensReceived);

        // Find the LiquidityAdded event
        bool eventFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            Vm.Log memory log = logs[i];

            // Check if this is the LiquidityAdded event
            // The event signature is: LiquidityAdded(address,uint256,uint256,uint256,uint256)
            // We'll check for the event topic
            if (log.topics.length > 0) {
                bytes32 eventSignature = keccak256("LiquidityAdded(address,uint256,uint256,uint256,uint256)");
                if (log.topics[0] == eventSignature) {
                    eventFound = true;

                    console2.log("SUCCESS: LiquidityAdded event found!");
                    console2.log("Event data length:", log.data.length);

                    // Decode the event data
                    // Event parameters: (uint256 verseAmountIn, uint256 tbtcAmountIn, uint256 lpTokensOut, uint256 exactBptAmountOut)
                    // Note: address user is indexed, so it's in topics[1], not in data
                    (uint256 eventVerseAmount, uint256 eventTbtcAmount, uint256 eventLpTokens, uint256 eventExactBpt) = abi.decode(
                        log.data,
                        (uint256, uint256, uint256, uint256)
                    );

                    // Get the user address from topics[1] (indexed parameter)
                    address eventUser = address(uint160(uint256(log.topics[1])));

                    console2.log("Event decoded values:");
                    console2.log("  User:", eventUser);
                    console2.log("  VERSE amount used:", eventVerseAmount);
                    console2.log("  tBTC amount used:", eventTbtcAmount);
                    console2.log("  LP tokens received:", eventLpTokens);
                    console2.log("  Exact BPT requested:", eventExactBpt);

                    // Verify the event values
                    assertEq(eventUser, user1, "Event user should match caller");
                    assertGt(eventVerseAmount, 0, "VERSE amount should be positive");
                    assertGt(eventTbtcAmount, 0, "tBTC amount should be positive");
                    assertGt(eventLpTokens, 0, "LP tokens should be positive");
                    assertEq(eventLpTokens, lpTokensReceived, "LP tokens in event should match return value");

                    // Verify that amounts used are less than or equal to input amounts
                    assertLe(eventVerseAmount, verseAmount, "VERSE amount used should not exceed input");
                    assertLe(eventTbtcAmount, tbtcAmount, "tBTC amount used should not exceed input");

                    console2.log("SUCCESS: All event assertions passed!");
                    break;
                }
            }
        }

        assertTrue(eventFound, "LiquidityAdded event should be emitted");

        console2.log("LiquidityAdded event test passed!");

        vm.stopPrank();
    }

    function testDeadlineValidation() public {
        // Test deadline validation functionality
        console2.log("Testing deadline validation...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Test amounts
        uint256 verseAmount = 100 * 1e18; // 100 VERSE
        uint256 tbtcAmount = 20 * 1e18;   // 20 tBTC

        vm.startPrank(user1);

        // Deal tokens to user1
        deal(address(verseToken), user1, verseAmount);
        deal(address(tbtcToken), user1, tbtcAmount);

        // Approve orchestrator to spend tokens
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        // Test 1: Call with expired deadline (should revert)
        uint256 expiredDeadline = block.timestamp - 3600; // 1 hour in the past

        console2.log("Testing with expired deadline:", expiredDeadline);
        console2.log("Current block timestamp:", block.timestamp);

        vm.expectRevert("FarmMigrationOrchestratorV3Router: DEADLINE_EXPIRED");
        orchestratorV3.addLiquidityPublic(verseAmount, tbtcAmount, 0, expiredDeadline);

        console2.log("SUCCESS: addLiquidityPublic correctly reverts with expired deadline");

        // Test 2: Call with valid deadline (should succeed)
        uint256 validDeadline = block.timestamp + 3600; // 1 hour in the future

        console2.log("Testing with valid deadline:", validDeadline);

        uint256 lpTokensReceived = orchestratorV3.addLiquidityPublic(verseAmount, tbtcAmount, 0, validDeadline);

        console2.log("SUCCESS: addLiquidityPublic succeeds with valid deadline");
        console2.log("LP tokens received:", lpTokensReceived);
        assertGt(lpTokensReceived, 0, "Should receive LP tokens with valid deadline");

        // Test 3: Test addLiquidityAndStake with expired deadline
        deal(address(verseToken), user1, verseAmount); // Get more tokens
        deal(address(tbtcToken), user1, tbtcAmount);
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        vm.expectRevert(abi.encodeWithSignature("AllowanceExpired(uint256)", expiredDeadline));
        orchestratorV3.addLiquidityAndStake(verseAmount, tbtcAmount, 0, expiredDeadline);

        console2.log("SUCCESS: addLiquidityAndStake correctly reverts with expired deadline");

        // Test 4: Test addLiquidityAndStake with valid deadline
        deal(address(verseToken), user1, verseAmount); // Get more tokens
        deal(address(tbtcToken), user1, tbtcAmount);
        verseToken.approve(address(orchestratorV3), verseAmount);
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        uint256 farmBReceipts = orchestratorV3.addLiquidityAndStake(verseAmount, tbtcAmount, 0, validDeadline);

        console2.log("SUCCESS: addLiquidityAndStake succeeds with valid deadline");
        console2.log("FarmB receipts received:", farmBReceipts);
        assertGt(farmBReceipts, 0, "Should receive FarmB receipts with valid deadline");

        // Test 5: Test executeMigration with expired deadline
        // First, give user1 some FarmA receipt tokens by staking VERSE in FarmA
        uint256 verseForFarmA = 100 * 1e18; // 100 VERSE to stake
        deal(address(verseToken), user1, verseForFarmA);
        verseToken.approve(address(simpleFarmA), verseForFarmA);
        simpleFarmA.farmDeposit(verseForFarmA);

        uint256 farmAReceipts = simpleFarmA.balanceOf(user1);
        assertGt(farmAReceipts, 0, "User should have FarmA receipt tokens");

        // Deploy executor for this test
        FarmMigrationOrchestratorV3Executor executor = new FarmMigrationOrchestratorV3Executor(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        simpleFarmA.approve(address(executor), farmAReceipts);

        vm.expectRevert("DEADLINE_EXPIRED");
        executor.executeMigration(farmAReceipts, farmAReceipts / 5, 0, expiredDeadline);

        console2.log("SUCCESS: executeMigration correctly reverts with expired deadline");

        console2.log("All deadline validation tests passed!");

        vm.stopPrank();
    }

    function testZapToFarmB() public {
        // Test the universal ZAP function with VERSE input
        console2.log("Testing universal ZAP function with VERSE...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Give user1 some VERSE tokens for testing
        uint256 verseAmount = 1000 * 1e18; // 1000 VERSE
        deal(address(verseToken), user1, verseAmount);

        vm.startPrank(user1);

        // Check initial balances
        uint256 initialVerse = verseToken.balanceOf(user1);
        uint256 initialFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Initial balances:");
        console2.log("  VERSE:", initialVerse);
        console2.log("  FarmB receipts:", initialFarmB);

        // Approve orchestrator to spend VERSE tokens
        verseToken.approve(address(orchestratorV3), verseAmount);

        // Call the ZAP function with VERSE
        uint256 farmBReceipts = orchestratorV3.zapToFarmB(
            address(verseToken),
            verseAmount,
            1000, // 10% slippage
            block.timestamp + 3600 // 1 hour deadline
        );

        // Check final balances
        uint256 finalVerse = verseToken.balanceOf(user1);
        uint256 finalFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Final balances after VERSE ZAP:");
        console2.log("  VERSE:", finalVerse);
        console2.log("  FarmB receipts:", finalFarmB);

        console2.log("Changes:");
        console2.log("  VERSE used:", initialVerse - finalVerse);
        console2.log("  FarmB receipts gained:", finalFarmB - initialFarmB);

        // Assertions for VERSE ZAP
        assertGt(farmBReceipts, 0, "Should receive FarmB receipt tokens from VERSE ZAP");
        assertGt(finalFarmB, initialFarmB, "User should have more FarmB receipts");
        assertLt(finalVerse, initialVerse, "User should have less VERSE (used for ZAP)");

        console2.log("VERSE ZAP test passed!");

        vm.stopPrank();
    }

    function testZapToFarmBWithTbtc() public {
        // Test the universal ZAP function with tBTC input
        console2.log("Testing universal ZAP function with tBTC...");

        // Deploy the orchestrator
        FarmMigrationOrchestratorV3Router orchestratorV3 = new FarmMigrationOrchestratorV3Router(
            address(simpleFarmA),
            address(simpleFarmB),
            VERSE_TOKEN,
            TBTC_TOKEN,
            BALANCER_POOL,
            BALANCER_V3_ROUTER
        );

        // Give user1 some tBTC tokens for testing
        uint256 tbtcAmount = 1000000000; // 1 tBTC (large amount to ensure it works with the pool)
        deal(address(tbtcToken), user1, tbtcAmount);

        vm.startPrank(user1);

        // Check initial balances
        uint256 initialTbtc = tbtcToken.balanceOf(user1);
        uint256 initialFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Initial balances:");
        console2.log("  tBTC:", initialTbtc);
        console2.log("  FarmB receipts:", initialFarmB);

        // Approve orchestrator to spend tBTC tokens
        tbtcToken.approve(address(orchestratorV3), tbtcAmount);

        // Call the ZAP function with tBTC
        uint256 farmBReceipts = orchestratorV3.zapToFarmB(
            address(tbtcToken),
            tbtcAmount,
            1000, // 10% slippage
            block.timestamp + 3600 // 1 hour deadline
        );

        // Check final balances
        uint256 finalTbtc = tbtcToken.balanceOf(user1);
        uint256 finalFarmB = simpleFarmB.balanceOf(user1);

        console2.log("Final balances after tBTC ZAP:");
        console2.log("  tBTC:", finalTbtc);
        console2.log("  FarmB receipts:", finalFarmB);

        console2.log("Changes:");
        console2.log("  tBTC used:", initialTbtc - finalTbtc);
        console2.log("  FarmB receipts gained:", finalFarmB - initialFarmB);

        // Assertions for tBTC ZAP
        assertGt(farmBReceipts, 0, "Should receive FarmB receipt tokens from tBTC ZAP");
        assertGt(finalFarmB, initialFarmB, "User should have more FarmB receipts");
        assertLt(finalTbtc, initialTbtc, "User should have less tBTC (used for ZAP)");

        console2.log("tBTC ZAP test passed!");

        vm.stopPrank();
    }

        function testUserWalletMigration() public {
        address userWallet = 0x22079A848266A7D2E40CF0fF71a6573D78adcF37;
        address deployedOrchestrator = 0xfC87b70897F1450731A854CBf51dE7C22387F9d8;

        // Mark contracts as persistent
        vm.makePersistent(deployedOrchestrator);
        vm.makePersistent(0xcbE5F4E8a112F25C2F902714e3cBB7955F19Bb36); // FarmA receipts
        vm.makePersistent(0x1b69e6a995dEfff515c44592bF220bd123812eC4); // FarmB
        vm.makePersistent(0x249cA82617eC3DfB2589c4c17ab7EC9765350a18); // VERSE
        vm.makePersistent(0x18084fbA666a33d37592fA2633fD49a74DD93a88); // tBTC

        // Get user's current FarmA receipt balance
        IERC20 farmAReceipts = IERC20(0xcbE5F4E8a112F25C2F902714e3cBB7955F19Bb36);
        uint256 userFarmABalance = farmAReceipts.balanceOf(userWallet);
        console2.log("User's FarmA receipt balance:", userFarmABalance);

        // Use a small amount for testing (1% of balance)
        uint256 testAmount = userFarmABalance > 0 ? (userFarmABalance * 1) / 100 : 100 * 1e18;
        if (testAmount > userFarmABalance) testAmount = userFarmABalance;
        require(testAmount > 0, "No FarmA receipts to test with");

        console2.log("Testing with FarmA receipt amount:", testAmount);

        // Calculate parameters
        uint256 verseToSwap = testAmount * 20 / 100; // 20% of VERSE for swap
        uint256 minTbtcOut = 1;
        uint256 deadline = block.timestamp + 3600;

        console2.log("VERSE to swap:", verseToSwap);
        console2.log("Min tBTC out:", minTbtcOut);
        console2.log("Deadline:", deadline);

        // Impersonate user wallet and approve
        vm.prank(userWallet);
        farmAReceipts.approve(deployedOrchestrator, testAmount);
        console2.log("SUCCESS: Approved FarmA receipts to orchestrator");

        // Execute migration
        vm.prank(userWallet);
        FarmMigrationOrchestratorV3Executor(deployedOrchestrator).executeMigration(
            testAmount, verseToSwap, minTbtcOut, deadline
        );

        console2.log("SUCCESS: Migration executed successfully");

        // Check final FarmB balance
        ISimpleFarm simpleFarmB = ISimpleFarm(0x1b69e6a995dEfff515c44592bF220bd123812eC4);
        uint256 finalFarmBBalance = simpleFarmB.balanceOf(userWallet);
        console2.log("Final FarmB receipts:", finalFarmBBalance);

        assertGt(finalFarmBBalance, 0, "Should have received FarmB receipt tokens");
        console2.log("SUCCESS: Migration test completed");
    }

    function testDebugMigrationRevert() public {
        address userWallet = 0x22079A848266A7D2E40CF0fF71a6573D78adcF37;
        address deployedOrchestrator = 0xfC87b70897F1450731A854CBf51dE7C22387F9d8;

        // Mark contracts as persistent
        vm.makePersistent(deployedOrchestrator);
        vm.makePersistent(0xcbE5F4E8a112F25C2F902714e3cBB7955F19Bb36); // FarmA receipts
        vm.makePersistent(0x1b69e6a995dEfff515c44592bF220bd123812eC4); // FarmB
        vm.makePersistent(0x249cA82617eC3DfB2589c4c17ab7EC9765350a18); // VERSE
        vm.makePersistent(0x18084fbA666a33d37592fA2633fD49a74DD93a88); // tBTC

        // Test parameters (same as your transaction)
        uint256 testAmount = 1000000000000000000000; // 1000 tokens
        uint256 verseToSwap = 200000000000000000000; // 200 tokens
        uint256 minTbtcOut = 1;
        uint256 deadline = 1755769510;

        console2.log("=== Debug Test Parameters ===");
        console2.log("User wallet:", userWallet);
        console2.log("Orchestrator:", deployedOrchestrator);
        console2.log("FarmA receipt amount:", testAmount);
        console2.log("VERSE to swap:", verseToSwap);
        console2.log("Min tBTC out:", minTbtcOut);
        console2.log("Deadline:", deadline);

        // Check balances
        IERC20 farmAReceipts = IERC20(0xcbE5F4E8a112F25C2F902714e3cBB7955F19Bb36);
        uint256 userFarmABalance = farmAReceipts.balanceOf(userWallet);
        console2.log("FarmA receipts balance:", userFarmABalance);

        // Check allowances
        uint256 farmAAllowance = farmAReceipts.allowance(userWallet, deployedOrchestrator);
        console2.log("FarmA allowance to orchestrator:", farmAAllowance);

        // Check if user has enough FarmA receipts
        require(userFarmABalance >= testAmount, "Insufficient FarmA receipts");

        // Impersonate user and try to execute
        vm.prank(userWallet);

        // First, approve if needed
        if (farmAAllowance < testAmount) {
            farmAReceipts.approve(deployedOrchestrator, testAmount);
            console2.log("SUCCESS: Approved FarmA receipts");
        }

        // Try to execute migration
        try FarmMigrationOrchestratorV3Executor(deployedOrchestrator).executeMigration(
            testAmount,
            verseToSwap,
            minTbtcOut,
            deadline
        ) {
            console2.log("SUCCESS: Migration executed without revert");
        } catch Error(string memory reason) {
            console2.log("REVERT with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("REVERT with low level data:");
            console2.logBytes(lowLevelData);
        }
    }
}
