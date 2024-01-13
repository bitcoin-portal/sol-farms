// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.23;

import "./IERC20.sol";

interface ITimeLockFarmV2Dual {

    function makeDepositForUser(
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime
    )
        external;

    function stakeToken()
        external
        view
        returns (address);

    function rewardTokenB()
        external
        view
        returns (address);

    function setRewardRates(
        uint256 newRateA,
        uint256 newRateB
    )
        external;
}

contract ManagerSetup {

    IERC20 public immutable VERSE;
    IERC20 public immutable STABLECOIN;

    struct Allocation {
        bool unlock20Percent;
        address stakeOwner;
        uint256 stakeAmount;
        uint256 vestingTime;
    }

    Allocation[] public allocations;
    address public immutable WORKER_ADDRESS;
    ITimeLockFarmV2Dual public immutable TIME_LOCK_FARM;

    address public owner;
    bool public isInitialized;

    modifier onlyWorker() {
        require(
            msg.sender == WORKER_ADDRESS,
            "ManagerSetup: NOT_OWNER"
        );
        _;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "ManagerSetup: NOT_OWNER"
        );
        _;
    }

    constructor(
        ITimeLockFarmV2Dual _timeLockFarm
    ) {
        TIME_LOCK_FARM = _timeLockFarm;
        WORKER_ADDRESS = msg.sender;

        owner = msg.sender;

        VERSE = IERC20(
            TIME_LOCK_FARM.stakeToken()
        );

        STABLECOIN = IERC20(
            TIME_LOCK_FARM.rewardTokenB()
        );

        VERSE.approve(
            address(TIME_LOCK_FARM),
            type(uint256).max
        );

        STABLECOIN.approve(
            address(TIME_LOCK_FARM),
            type(uint256).max
        );

        uint256 fourYears = 365 days * 4;

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x01b7b155f4934d52AAb625E8F7f20F81f78211Aa,
                stakeAmount: 56_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x0CefAbb19e909Dee95CFa1F007a20AFdcF9020d1,
                stakeAmount: 50_000_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x104aA2d7195Ce3f445c9B675b80960181e062357,
                stakeAmount: 37_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x12357c21d95eB08E2D9C9262Edf6e09306de801d,
                stakeAmount: 31_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x13879cB7382c64Fa84FA4ecdE79dc8ae8EEA3E2e,
                stakeAmount: 25_000_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x181f392eb50bD52d03aA473982eDd568d449b20A,
                stakeAmount: 18_750_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x1B006a0318dF1cBcC072D1505F641796E0EA59B3,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x1C5Cb9daFaBd8CBA532e52eF30A3C14cCCba06E8,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x2062C4515f7DF5B0D71A3450e5cD5574b507ba3a,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x216b6F99CA2bf53d801fE9Ba7d68fADC4949249B,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x21F107026a0f746b81Fb0A47A1314f4AB4390B63,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x2d75e5D15837D780e751e2d4133cF59Dca281200,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x3b28c1fF09c72915A1bd44C8A5c8C9018159b4C2,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x3cee2c3869e5477FC56eCb2009167899415D7fBF,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x44a5eeE514A39B0c2e887A5a403170d84C563423,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x50319e5033010395C7da40f27C37Ed4BB2E92d6D,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x566CAd1FBA28aC265f046579261695D4c9F6d4da,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x568CE9c5a37E434a5521E3a8230b8D357cE89330,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x5f21e45CED3C5a8d4F6dCd0550a5541eaa15f36E,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x636EE9dd1a3F9b85A78b8c08c1E5A8506703fc8A,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );
    }

    function setRewardRates(
        uint256 _newRateA,
        uint256 _newRateB
    )
        external
        onlyWorker
    {
        TIME_LOCK_FARM.setRewardRates(
            _newRateA,
            _newRateB
        );
    }

    /**
     * @dev Allows to recover ANY tokens
     * from the private farm contract.
     * God mode feature for admin multisig.
     */
    function recoverTokens(
        IERC20 tokenAddress,
        uint256 tokenAmount
    )
        external
        onlyOwner
    {
        IERC20(tokenAddress).transfer(
            owner,
            tokenAmount
        );
    }

    function executeAllocations()
        external
        onlyOwner
    {
        require(
            isInitialized == false,
            "ManagerSetup: ALREADY_INITIALIZED"
        );

        isInitialized = true;

        uint256 i;
        uint256 l = allocations.length;

        while (i < l) {
            bool res = _executeAllocation(
                allocations[i]
            );

            require(
                res == allocations[i].unlock20Percent,
                "ManagerSetup: ALLOCATION_MALFORMED"
            );

            unchecked {
                ++i;
            }
        }
    }

    function _executeAllocation(
        Allocation memory allocation
    )
        internal
        returns (bool)
    {
        if (allocation.unlock20Percent == true) {

            TIME_LOCK_FARM.makeDepositForUser({
                _stakeOwner: allocation.stakeOwner,
                _stakeAmount: get20Percent(allocation.stakeAmount),
                _lockingTime: 0
            });

            TIME_LOCK_FARM.makeDepositForUser({
                _stakeOwner: allocation.stakeOwner,
                _stakeAmount: get80Percent(allocation.stakeAmount),
                _lockingTime: allocation.vestingTime
            });

            return true;
        }

        TIME_LOCK_FARM.makeDepositForUser({
            _stakeOwner: allocation.stakeOwner,
            _stakeAmount: allocation.stakeAmount,
            _lockingTime: allocation.vestingTime
        });

        return false;
    }

    function get20Percent(
        uint256 _amount
    )
        public
        pure
        returns (uint256)
    {
        return _amount * 20E16;
    }

    function get80Percent(
        uint256 _amount
    )
        public
        pure
        returns (uint256)
    {
        return _amount * 80E16;
    }
}