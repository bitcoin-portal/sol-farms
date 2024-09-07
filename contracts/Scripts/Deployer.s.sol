// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.25;

import "forge-std/Script.sol";

import "../SimpleFarm.sol";
import { FarmFactory } from "../FarmFactory.sol";

import "../RescueSetup.sol";
import "../MigrationSetup.sol";
import "../TimeLockFarmV2Dual.sol";

contract DeployTimeLockFarmV2Dual is Script {

    function setUp() public {}

    function run() public {

        vm.startBroadcast(
            vm.envUint("PRIVATE_KEY")
        );

        TimeLockFarmV2Dual timeLock = new TimeLockFarmV2Dual(
            IERC20(0xc708D6F2153933DAA50B2D0758955Be0A93A8FEc),
            IERC20(0xc708D6F2153933DAA50B2D0758955Be0A93A8FEc),
            IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063),
            2592000
        );

        console.log(
            address(timeLock),
            "timeLock"
        );

        vm.stopBroadcast();
    }
}

contract DeployManager is Script {

    function setUp() public {}

    function run() public {

        vm.startBroadcast(
            vm.envUint("PRIVATE_KEY")
        );

        ManagerSetup manager = new ManagerSetup(
            0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
            0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
            0x78190e4c7C7B2c2C3b0562F1f155a1FC2F5160CA
        );

        console.log(
            address(manager),
            "manager"
        );

        vm.stopBroadcast();
    }
}

contract DeployMigration is Script {

    function setUp() public {}

    function run() public {

        vm.startBroadcast(
            vm.envUint("PRIVATE_KEY")
        );

        MigrationSetup migration = new MigrationSetup(
            0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
            0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
            0x775573fC6A3E9E1f9a12E21B504073c0D66F4ef4,
            0x78190e4c7C7B2c2C3b0562F1f155a1FC2F5160CA
        );

        console.log(
            address(migration),
            "migration"
        );

        vm.stopBroadcast();
    }
}

contract DeployRescue is Script {

    function setUp() public {}

    function run() public {

        vm.startBroadcast(
            vm.envUint("PRIVATE_KEY")
        );

        RescueSetup rescue = new RescueSetup(
            0x775573fC6A3E9E1f9a12E21B504073c0D66F4ef4,
            0x09389844EB4A5DA62bc7590ae0C1Ec0dA71A4F82
        );

        console.log(
            address(rescue),
            "rescue"
        );

        vm.stopBroadcast();
    }
}

contract DeploySimpleFarm is Script {

    function setUp() public {}

    function run() public {

        uint256 DEFAULT_DURATION = 2592000;
        address WZANO_USDT_LP = 0x294fff8FbfE37dA6FFD410b4cA370b92AE853a9B;
        // address VERSE_TOKEN = 0x249cA82617eC3DfB2589c4c17ab7EC9765350a18;
        address WZANO_TOKEN = 0xdb85f6685950E285b1E611037BEBe5B34e2B7d78;
        address OWNER = 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689;

        vm.startBroadcast(
            vm.envUint("PRIVATE_KEY")
        );

        SimpleFarm farm = new SimpleFarm();

        farm.initialize(
            WZANO_USDT_LP,
            WZANO_TOKEN,
            DEFAULT_DURATION,
            OWNER,
            OWNER
        );

        console.log(
            address(farm),
            "farm"
        );

        vm.stopBroadcast();
    }
}

contract DeployFarmFactory is Script {

    function setUp() public {}

    function run() public {

        vm.startBroadcast(
            vm.envUint("PRIVATE_KEY")
        );

        address implementation = address (
            0x545465f965c3Fdfb97Af0328E458ed66514bE286
        );

        FarmFactory factory = new FarmFactory(
            implementation
        );

        console.log(
            address(factory),
            "factory"
        );

        vm.stopBroadcast();
    }
}