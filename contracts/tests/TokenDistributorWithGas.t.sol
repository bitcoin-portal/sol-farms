// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.26;

import "forge-std/Test.sol";
import "../TokenDistributorWithGas.sol";
import "../TestToken.sol";

contract TokenDistributorWithGasTest is Test {

    TokenDistributorWithGas public distributor;
    TestToken public token;

    address public owner;
    address public alice;
    address public bob;
    address public carol;

    uint256 constant ONE_TOKEN = 1 ether;
    uint256 constant POINT_ONE_ETH = 0.1 ether;
    uint256 constant POINT_ZERO_ONE_ETH = 0.01 ether;

    function setUp()
        public
    {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        distributor = new TokenDistributorWithGas();
        token = new TestToken();

        // Fund distributor with ETH for gas distribution
        vm.deal(address(distributor), 1 ether);

        // Fund distributor with tokens
        token.transfer(address(distributor), 1000 ether);

        // Give carol some ETH
        vm.deal(carol, 1 ether);
    }

    function testInitialValues()
        public
    {
        assertEq(distributor.owner(), owner);
        assertEq(distributor.manager(), owner);
        assertEq(distributor.gasThreshold(), POINT_ONE_ETH);
        assertEq(distributor.gasAmount(), POINT_ONE_ETH);
    }

    function testSetGasThreshold()
        public
    {
        uint256 newThreshold = 0.2 ether;
        distributor.setGasThreshold(newThreshold);
        assertEq(distributor.gasThreshold(), newThreshold);
    }

    function testFailSetGasThresholdNonOwner()
        public
    {
        vm.prank(alice);
        distributor.setGasThreshold(0.2 ether);
    }

    function testSetGasAmount()
        public
    {
        uint256 newAmount = 0.02 ether;
        distributor.setGasAmount(newAmount);
        assertEq(distributor.gasAmount(), newAmount);
    }

    function testFailSetGasAmountNonOwner()
        public
    {
        vm.prank(alice);
        distributor.setGasAmount(0.02 ether);
    }

    function testSendTokensWithGasToLowBalance()
        public
    {
        // Ensure bob has very low balance
        assertEq(bob.balance, 0);

        address[] memory recipients = new address[](1);
        recipients[0] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ONE_TOKEN;

        uint256 bobBalanceBefore = bob.balance;
        uint256 bobTokenBalanceBefore = token.balanceOf(bob);

        distributor.sendTokensWithGas(address(token), recipients, amounts);

        assertEq(
            bob.balance - bobBalanceBefore,
            distributor.gasAmount()
        );

        assertEq(
            token.balanceOf(bob) - bobTokenBalanceBefore,
            ONE_TOKEN
        );
    }

    function testSendTokensWithoutGasToSufficientBalance()
        public
    {
        address[] memory recipients = new address[](1);
        recipients[0] = carol;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ONE_TOKEN;

        uint256 carolBalanceBefore = carol.balance;
        uint256 carolTokenBalanceBefore = token.balanceOf(carol);

        distributor.sendTokensWithGas(address(token), recipients, amounts);

        assertEq(carol.balance, carolBalanceBefore);
        assertEq(
            token.balanceOf(carol) - carolTokenBalanceBefore,
            ONE_TOKEN
        );
    }

    function testSendTokensWithGasEmitsEvent()
        public
    {
        address[] memory recipients = new address[](1);
        recipients[0] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ONE_TOKEN;

        vm.expectEmit(true, false, false, true);
        emit TokenDistributorWithGas.GasTransferred(
            bob,
            distributor.gasAmount()
        );

        distributor.sendTokensWithGas(
            address(token),
            recipients,
            amounts
        );
    }

    function testFailSendTokensInvalidArrayLengths()
        public
    {
        address[] memory recipients = new address[](2);
        recipients[0] = bob;
        recipients[1] = carol;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ONE_TOKEN;

        distributor.sendTokensWithGas(
            address(token),
            recipients,
            amounts
        );
    }

    function testMultipleRecipientsWithGas()
        public
    {
        // Ensure both recipients have zero balance
        assertEq(alice.balance, 0);
        assertEq(bob.balance, 0);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ONE_TOKEN;
        amounts[1] = ONE_TOKEN;

        uint256 aliceBalanceBefore = alice.balance;
        uint256 bobBalanceBefore = bob.balance;
        uint256 distributorBalanceBefore = address(distributor).balance;

        distributor.sendTokensWithGas(address(token), recipients, amounts);

        // Both recipients should receive gas
        assertEq(
            alice.balance - aliceBalanceBefore,
            distributor.gasAmount()
        );

        assertEq(
            bob.balance - bobBalanceBefore,
            distributor.gasAmount()
        );

        // Distributor balance should decrease by 2x gasAmount
        assertEq(
            distributorBalanceBefore - address(distributor).balance,
            distributor.gasAmount() * 2
        );

        // Both should receive tokens
        assertEq(token.balanceOf(alice), ONE_TOKEN);
        assertEq(token.balanceOf(bob), ONE_TOKEN);
    }

    function testOwnershipTransfer()
        public
    {
        distributor.proposeOwner(alice);
        assertEq(distributor.proposedOwner(), alice);

        vm.prank(alice);
        distributor.acceptOwnership();
        assertEq(distributor.owner(), alice);
        assertEq(distributor.proposedOwner(), address(0x0));

        // Only new owner can set gas parameters
        vm.prank(alice);
        distributor.setGasAmount(0.05 ether);
        assertEq(distributor.gasAmount(), 0.05 ether);

        // Old owner should no longer have access
        vm.expectRevert("TokenDistributorWithGas: INVALID_OWNER");
        distributor.setGasThreshold(0.5 ether);
    }

    function testGasThresholdAdjustment()
        public
    {
        // Set threshold to exactly carol's balance
        vm.deal(carol, 0.5 ether);
        distributor.setGasThreshold(0.5 ether);

        address[] memory recipients = new address[](1);
        recipients[0] = carol;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ONE_TOKEN;

        uint256 carolBalanceBefore = carol.balance;

        distributor.sendTokensWithGas(address(token), recipients, amounts);

        // Carol should not receive gas as her balance equals threshold
        assertEq(carol.balance, carolBalanceBefore);

        // Lower threshold so carol will now receive gas
        distributor.setGasThreshold(0.6 ether);

        distributor.sendTokensWithGas(address(token), recipients, amounts);

        // Now carol should receive gas
        assertEq(carol.balance, carolBalanceBefore + distributor.gasAmount());
    }
}
