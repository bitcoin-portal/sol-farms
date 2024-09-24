// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

import "forge-std/Test.sol";

import "./RescueSetup.sol";
import "./ManagerSetup.sol";
import "./MigrationSetup.sol";
import "./TimeLockFarmV2Dual.sol";

contract MigrationSetupTest is Test {

    uint256 constant FORK_MAINNET_BLOCK = 56_606_831;

    TimeLockFarmV2Dual public farm = TimeLockFarmV2Dual(
        0x775573fC6A3E9E1f9a12E21B504073c0D66F4ef4
    );

    TimeLockFarmV2Dual public newFarm = TimeLockFarmV2Dual(
        0x78190e4c7C7B2c2C3b0562F1f155a1FC2F5160CA
    );

    ManagerSetup public manager = ManagerSetup(
        0x09389844EB4A5DA62bc7590ae0C1Ec0dA71A4F82
    );

    MigrationSetup public migration = MigrationSetup(
        0x18b72e397E703d1328DF67A1C416cED73786d5d5
    );

    RescueSetup public rescue = RescueSetup(
        0x7C1F4261B0712df196ecfbe818278f8cBF9Db606
    );

    IERC20 public verseToken = IERC20(
        0xc708D6F2153933DAA50B2D0758955Be0A93A8FEc
    );

    IERC20 public stableToken = IERC20(
        0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
    );

    address constant MANAGER_ADDRESS = address(
        0x09389844EB4A5DA62bc7590ae0C1Ec0dA71A4F82
    );

    address constant HOLDER_ADDRESS = address(
        0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689
    );

    address constant BEN_ADDRESS = address(
        0x1356ee38f20500F6176c45A3D42525fec5A986b5
    );

    address constant PAUL_ADDRESS = address(
        0x127564F78d371ECcE6Ab86A179Be4e4378B6ea3D
    );

    mapping(address => uint256) public rewardsBeforeMigrationOldFarmA;
    mapping(address => uint256) public rewardsBeforeMigrationOldFarmB;

    address constant ZERO_ADDRESS = address(0x0);
    uint256 public constant DEFAULT_DURATION = 30 days;
    bool public constant LOGS_ENABLE = true;

    function _log(
        uint256 _a,
        address _b
    )
        internal
        view
    {
        if (LOGS_ENABLE == true) {
            console.log(
                _a,
                _b
            );
        }
    }

    function _log(
        uint256 _amount,
        string memory _message
    )
        internal
        view
    {
        if (LOGS_ENABLE == true) {
            console.log(
                _amount,
                _message
            );
        }
    }

    function _log(
        address _addy,
        string memory _message
    )
        internal
        view
    {
        if (LOGS_ENABLE == true) {
            console.log(
                _addy,
                _message
            );
        }
    }

    function tokens(
        uint256 _amount
    )
        internal
        pure
        returns (uint256)
    {
        return _amount * 10 ** 18;
    }

    function setUp()
        public
    {
        vm.createSelectFork(
            vm.rpcUrl("polygon"),
            FORK_MAINNET_BLOCK
        );
    }

    function testRescueFunds()
        public
    {
        /*vm.warp(
            1708000000
        );
        */

        vm.startPrank(
            HOLDER_ADDRESS
        );

        verseToken.transfer(
            address(farm),
            tokens(123_335_000)
        );
        rescue.exitFarm();

        console.log(verseToken.balanceOf(address(farm)), 'verseToken in farm left');
        console.log(stableToken.balanceOf(address(farm)), 'stableToken in farm left');
        console.log(verseToken.balanceOf(address(newFarm)), 'verseToken in newFarm');
        // _performOperation();
        // _performOperation();
    }

    function _performOperation()
        internal
    {
        vm.startPrank(
            HOLDER_ADDRESS
        );

        rescue.enterRescueMode({
            _stakeAmount: tokens(1_000_000_000),
            _lockingTime: 10 minutes,
            _rewardDuration: 10 seconds,
            _rewardRateA: tokens(50_000_000)
        });

        _log(farm.earnedA(PAUL_ADDRESS), 'rewardForPaul before warp');
        _log(farm.earnedA(HOLDER_ADDRESS), 'rewardForUser before warp');
        _log(farm.earnedA(address(rescue)), 'RescueReward before warp');

        vm.warp(
            block.timestamp + 30 seconds
        );

        rescue.triggerFarmUpdate();

        _log(farm.earnedA(PAUL_ADDRESS), 'rewardForPaul after warp');
        _log(farm.earnedA(HOLDER_ADDRESS), 'rewardForUser after warp');
        _log(farm.earnedA(address(rescue)), 'RescueReward after warp');

        vm.warp(
            block.timestamp + 10 minutes
        );

        _log(farm.earnedA(PAUL_ADDRESS), 'rewardForPaul after 10 minutes');
        _log(farm.earnedA(HOLDER_ADDRESS), 'rewardForUser after 10 minutes');
        _log(farm.earnedA(address(rescue)), 'RescueReward after 10 minutes');

        vm.warp(
            block.timestamp + 20 minutes
        );

        _log(farm.earnedA(HOLDER_ADDRESS), 'rewardForUser after 20 minutes');
        _log(farm.earnedA(address(rescue)), 'RescueReward after 20 minutes');

        _log(verseToken.balanceOf(address(farm)), 'verse In farm');

        rescue.exitFarmPrepareRepeat();

        _log(verseToken.balanceOf(address(farm)), 'verse In farm');
        _log(verseToken.balanceOf(address(rescue)), 'RescueReward balance after exit');
        _log(verseToken.balanceOf(MANAGER_ADDRESS), 'Manager balance after exit');

        vm.stopPrank();

        vm.warp(
            block.timestamp + 5 minutes
        );
    }
}
