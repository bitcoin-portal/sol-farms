// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.26;

import "forge-std/Test.sol";
import "../TokenDistributor.sol";
import "../IERC20.sol";

contract TokenDistributorTest is Test {

    address public constant DEPLOYER = 0x75aa660720f3dcb5973DA8A81450647C18ae35E4;
    address public constant TARGET_CONTRACT_ADDRESS = 0x149d859641999ADE76A54f75106cc77B8A0bBC67;
    address public constant TOKEN_ADDRESS = 0x249cA82617eC3DfB2589c4c17ab7EC9765350a18;
    TokenDistributor public distributor;

    function setUp() public {
        // Fork from the specified block
        vm.createSelectFork("mainnet", 22344716);
    }

    function testMultipleDeployments() public {
        // Impersonate the deployer address
        vm.startPrank(
            DEPLOYER
        );

        console.log("Deploying TokenDistributor 16 times from same address:");

        for (uint256 i = 0; i < 16; i++) {
            distributor = new TokenDistributor();
            console.log(string.concat("Deployment ", vm.toString(i + 1), ": ", vm.toString(address(distributor))));

            // Check if this is the target contract
            if (address(distributor) == TARGET_CONTRACT_ADDRESS) {
                console.log("Found target contract at deployment ", vm.toString(i + 1));

                // Define the token
                distributor.defineToken(TOKEN_ADDRESS);
                console.log("Token defined:", vm.toString(TOKEN_ADDRESS));

                // Check the token balance
                IERC20 token = IERC20(TOKEN_ADDRESS);
                uint256 tokenBalance = token.balanceOf(address(distributor));
                console.log("Contract token balance:", tokenBalance);

                // Send all tokens back to deployer
                address[] memory recipients = new address[](1);
                recipients[0] = DEPLOYER;

                uint256[] memory amounts = new uint256[](1);
                amounts[0] = tokenBalance;

                if (tokenBalance > 0) {
                    console.log("Sending all tokens to deployer:", tokenBalance);
                    distributor.sendTokens(recipients, amounts);

                    // Verify transfer
                    uint256 deployerBalanceAfter = token.balanceOf(DEPLOYER);
                    console.log("Deployer balance after transfer:", deployerBalanceAfter);
                } else {
                    console.log("No tokens to transfer");
                }
            }
        }

        vm.stopPrank();
    }
}