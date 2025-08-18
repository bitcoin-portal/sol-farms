// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "../FarmMigrationOrchestratorV3Executor.sol";
import "forge-std/Script.sol";

contract DeployMigrationOrchestrator is Script {
    // Mainnet addresses from tests
    address constant VERSE_TOKEN = 0x249cA82617eC3DfB2589c4c17ab7EC9765350a18; // VERSE on mainnet
    address constant TBTC_TOKEN = 0x18084fbA666a33d37592fA2633fD49a74DD93a88; // tBTC on mainnet
    address constant BALANCER_POOL = 0x02345DA85777B7E5ED740E0Df3BBcA93EF03fe9f; // The specific V3 pool
    address constant BALANCER_V3_ROUTER = 0xAE563E3f8219521950555F5962419C8919758Ea2; // Balancer V3 Router

    // Already deployed farm addresses
    address constant FARM_A = 0xcbE5F4E8a112F25C2F902714e3cBB7955F19Bb36; // FarmA receipt tokens (DynamicRewardFarm)
    address constant FARM_B = 0x1b69e6a995dEfff515c44592bF220bd123812eC4; // FarmB for LP tokens

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the orchestrator executor
        console.log("Deploying FarmMigrationOrchestratorV3Executor...");
        FarmMigrationOrchestratorV3Executor executor = new FarmMigrationOrchestratorV3Executor(
            FARM_A,                 // SimpleFarm A (already deployed)
            FARM_B,                 // SimpleFarm B (already deployed)
            VERSE_TOKEN,            // VERSE token
            TBTC_TOKEN,             // tBTC token
            BALANCER_POOL,          // Balancer Pool
            BALANCER_V3_ROUTER      // Balancer V3 Router
        );

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("FarmMigrationOrchestratorV3Executor deployed at:", address(executor));
        console.log("Farm A (VERSE farm):", FARM_A);
        console.log("Farm B (LP farm):", FARM_B);
        console.log("VERSE Token:", VERSE_TOKEN);
        console.log("tBTC Token:", TBTC_TOKEN);
        console.log("Balancer Pool:", BALANCER_POOL);
        console.log("Balancer V3 Router:", BALANCER_V3_ROUTER);
    }
}
