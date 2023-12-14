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
}

contract ManagerSetup {

    IERC20 public immutable VERSE;

    struct Allocation {
        address stakeOwner;
        uint256 stakeAmount;
        uint256 vestingTime;
    }

    Allocation[] public allocations;
    address public immutable WORKER_ADDRESS;
    ITimeLockFarmV2Dual public immutable TIME_LOCK_FARM;

    address public owner;

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

        VERSE.approve(
            address(TIME_LOCK_FARM),
            type(uint256).max
        );

        uint256 fourYears = 365 days * 4;

        allocations.push(
            Allocation({
                stakeOwner: 0x08A39aE0b0dA06fE824a65fA0A73C3126A82A0bA,
                stakeAmount: 56_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                stakeOwner: 0xB413C4cF16A50E45D4101380AA0EDC1859Aa0a03,
                stakeAmount: 50_000_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                stakeOwner: 0xA02351E83625c5185908835846B26719Fcd3d53F,
                stakeAmount: 37_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                stakeOwner: 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
                stakeAmount: 31_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                stakeOwner: 0xE482Bd6f975fF1dda8f2FD375CA193DaCD38235a,
                stakeAmount: 25_000_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                stakeOwner: 0x717d52e84eF30875De52834603c112675CeDB7CA,
                stakeAmount: 18_750_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                stakeOwner: 0xa803c226c8281550454523191375695928DcFE92,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
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

    function tokenApprove(
        IERC20 _token,
        address _spender,
        uint256 _amount
    )
        external
        onlyOwner
    {
        _token.approve(
            _spender,
            _amount
        );
    }

    function executeAllocations()
        external
        onlyOwner
    {
        uint256 i;
        uint256 l = allocations.length;

        while (i < l) {
            _executeAllocation(
                allocations[i]
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
    {
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