// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.23;

import "forge-std/Test.sol";
import "./PrivateFarm2X.sol";

contract PrivateFarmTest is Test {

    PrivateFarm2X public farm;

    IERC20 USDC_TOKEN = IERC20(
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
    );

    IERC20 VERSE_TOKEN = IERC20(
        0x249cA82617eC3DfB2589c4c17ab7EC9765350a18
    );

    uint256 constant FORK_MAINNET_BLOCK = 18_704_404;

    address constant ADMIN_ADDRESS = address(
        0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689
    );

    uint256 public constant DEFAULT_DURATION = 30 days;

    function setUp()
        public
    {
        vm.createSelectFork(
            vm.rpcUrl("mainnet"),
            FORK_MAINNET_BLOCK
        );

        vm.startPrank(
            ADMIN_ADDRESS
        );

        farm = new PrivateFarm2X({
            _stakeToken: VERSE_TOKEN,
            _rewardTokenA: VERSE_TOKEN,
            _rewardTokenB: USDC_TOKEN,
            _defaultDuration: DEFAULT_DURATION
        });

        VERSE_TOKEN.approve(
            address(farm),
            type(uint256).max
        );

        USDC_TOKEN.approve(
            address(farm),
            type(uint256).max
        );
    }

    function testChangeDuration()
        public
    {
        uint256 expectedDuration = DEFAULT_DURATION;
        uint256 updatedDuration = 60 days;

        uint256 duration = farm.rewardDuration();

        assertEq(
            duration,
            expectedDuration
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
}
