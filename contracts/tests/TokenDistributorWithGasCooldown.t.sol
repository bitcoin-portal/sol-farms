// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.26;

import "forge-std/Test.sol";
import "../TokenDistributorWithGas.sol";
import "../TestToken.sol";

contract TokenDistributorWithGasCooldownTest is Test {
    TokenDistributorWithGas public distributor;
    TestToken public token;

    address public owner;
    address public alice;
    address public bob;

    uint256 constant ONE_TOKEN = 1 ether;
    uint256 constant POINT_ZERO_ONE_ETH = 0.01 ether;

    function setUp()
        public
    {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        distributor = new TokenDistributorWithGas();
        token = new TestToken();

        // Fund distributor with ETH for gas distribution
        vm.deal(address(distributor), 10 ether);

        // Fund distributor with tokens
        token.transfer(address(distributor), 1000 ether);

        // Fund bob with enough ETH to not trigger gas distribution
        vm.deal(bob, 1 ether);
    }

    function testCooldownSettings()
        public
    {
        // Check default settings
        assertEq(distributor.coolDown(), 2 minutes);

        // Update cooldown time
        uint256 newCooldown = 5 minutes;
        distributor.defineCoolDown(newCooldown);
        assertEq(distributor.coolDown(), newCooldown);
    }

    function testVisibilityOfEnableCoolDown()
        public
    {
        // Check that changeEnableCoolDown function exists and can be called
        // by the owner to toggle the cooldown functionality
        distributor.changeEnableCoolDown(true);
        distributor.changeEnableCoolDown(false);

        // Test that non-owners cannot call it
        vm.prank(alice);
        vm.expectRevert("TokenDistributorWithGas: INVALID_OWNER");
        distributor.changeEnableCoolDown(true);
    }
}