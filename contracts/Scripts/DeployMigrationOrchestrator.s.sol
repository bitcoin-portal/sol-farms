// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "../FarmMigrationOrchestratorV3Executor.sol";
import "forge-std/Script.sol";

contract DeployMigrationOrchestrator is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        FarmMigrationOrchestratorV3Executor executor = new FarmMigrationOrchestratorV3Executor(
            vm.envAddress("SIMPLE_FARM_A"),
            vm.envAddress("SIMPLE_FARM_B"),
            vm.envAddress("VERSE_TOKEN"),
            vm.envAddress("TBTC_TOKEN"),
            0x02345DA85777B7E5ED740E0Df3BBcA93EF03fe9f, // Balancer Pool
            0xAE563E3f8219521950555F5962419C8919758Ea2  // Balancer V3 Router
        );

        vm.stopBroadcast();

        console.log("FarmMigrationOrchestratorV3Executor deployed at:", address(executor));
    }
}
