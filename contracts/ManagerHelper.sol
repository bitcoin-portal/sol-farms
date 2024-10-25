// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.26;

struct Allocation {
    bool unlock20Percent;
    address stakeOwner;
    uint256 stakeAmount;
    uint256 lockingTime;
    uint256 initialTime;
}

struct UniqueAmount {
    uint256 amount;
    uint256 count;
}

contract ManagerHelper {

    Allocation[] public allocations;
    UniqueAmount[] public uniqueAmounts;

    uint256 public initialTokensRequired;
    uint256 FOUR_YEARS = 365 days * 4;

    uint256 public constant EXPECTED_ALLOCATIONS = 80;
    uint256 public constant EXPECTED_TOTAL_TOKENS = 6_393_750_000;

    mapping(address => uint256) public expectedInitialAmount;
    mapping(uint256 => uint256) public expectedUniqueAmounts;

    uint256 internal jan01_2024 = 1704067200;

    function _setupAllocations()
        internal
    {
        _pushAllocation(
            true,
            0x127564F78d371ECcE6Ab86A179Be4e4378B6ea3D,
            312_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x6fEeB0c3E25E5dEf17BC7274406F0674B8237038,
            312_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x568CE9c5a37E434a5521E3a8230b8D357cE89330,
            262_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x44a5eeE514A39B0c2e887A5a403170d84C563423,
            262_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
            187_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x1356ee38f20500F6176c45A3D42525fec5A986b5,
            187_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x7fae227057989C9bC0afAeCFEf18Bc68a6e03161,
            162_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xd360c96496eBF32cF0C71d568c3E95dfcB5cB704,
            137_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x2d75e5D15837D780e751e2d4133cF59Dca281200,
            137_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x181f392eb50bD52d03aA473982eDd568d449b20A,
            125_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x35e52181568f9245E6C040cB587970984369e104,
            112_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xe4CC1d1bBf5819F158ab0d0f65378AD9eD9bBC80,
            112_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x0CefAbb19e909Dee95CFa1F007a20AFdcF9020d1,
            100_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x606c633B612769B896be4BACC35c55973fDa7Bf7,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xE730A2803064Dd21915D436FE082C2e78e49590d,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x21F107026a0f746b81Fb0A47A1314f4AB4390B63,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xF33Ec3e5D76aA39504aa37548Bb7c0Cee9Bb45e0,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x3b28c1fF09c72915A1bd44C8A5c8C9018159b4C2,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x6db4F972AAA59DF869FD643925450211Acb097D5,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xb76296e5db55E30a94ae61A857A0e5DF40c86ef8,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xc69BCD45002514435E1525A5a1ad606e28572bbC,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xACa5d2a508d542DAaE3e340507D985A465c0E1a3,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xcb0d66a021463A4FD198290b53a8Bf3d1F58225b,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x680783fad0137725B06fBf2929565B38350A26E4,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x5cEDbA76c3987604c8c348E9accB9ca00d24F623,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x82C66CB5D6c6260979e604CeedA85635C74A175F,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xF7386F84dfA7b3ddA8c1790417F98713C7e03dF8,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xe2f858dBAC42a955f466c13ae20c664bDD1eFA6F,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x5f21e45CED3C5a8d4F6dCd0550a5541eaa15f36E,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x6D11be994Ea09E49705E480D836e2E887f041C3D,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x6c6bc62D7fF556f802810810bFDEEB01A1aFdbDf,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x69EBe456568948713CB6761D220a5c58E1315F39,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x74c363e7577A6B3830B5025f60204d686ED2D5af,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xE33C392d324332B34a5447C1f228Db557D68C180,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xea279533BA1458D55E29306E50c8939C2541Def3,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xe4a7F8d63d7211B8081D7c65C9e66188873FD113,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xE41b1aD07b9Ab7c8a28a8e491a76890eD6fB619b,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xd2281942Ec5231c71402954F823Cdb8Fad721327,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x82bCf2FceBBb6ba19d835c7397403b3922E74cb4,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x38Ec5897860Dfa500D20D8B8E16159f821031128,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xFf98222E3de88539A2496ed0AabB719AD00E2472,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x13879cB7382c64Fa84FA4ecdE79dc8ae8EEA3E2e,
            87_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xAd7741919812Fdae1cBB773A62613f3eb2C814d0,
            75_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xa474d76e79586A1179B825B5ED46d61Ee2183e3C,
            75_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x97123BD90Ecb6D807E61fae5019C6A608E008542,
            75_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x185254e29FC8A95C16f982bE061Cc5aeb5b94231,
            62_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x8aAfCb8a08E62f5902A468B98F0C519B2E0dFF50,
            62_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x3cee2c3869e5477FC56eCb2009167899415D7fBF,
            62_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xa46Cb95414f1a3952f5A9F1d6561084E27279EB3,
            62_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x81cDC1123382Ce7cc890D7D3D86bD3Da6EDCE78e,
            62_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xA5297Ac98A98Bc4E4c929137E04747DEF6830e66,
            56_250_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xbeB16AE9233cb2dA0cA985f45a0b72d99078fCC4,
            56_250_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x28484c3Bb9F10ac262A67041a273552BeEd7C661,
            56_250_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x8f4038F0B0FDfc8E8621e1e5a8Bcd951b0FB8Bc9,
            50_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x636EE9dd1a3F9b85A78b8c08c1E5A8506703fc8A,
            50_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x5F09C1D7d28F34FdD3a5492Cde34c74cB4875095,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x5c82AC87A41E7627EB9a43Cc584b5441C376D916,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x79Db74988EAb4b9Add9d41239a06FAe4b2820E61,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x104aA2d7195Ce3f445c9B675b80960181e062357,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x2062C4515f7DF5B0D71A3450e5cD5574b507ba3a,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xbA66e7784c83340F521553665F06e252452502C2,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xE1EfC068A1Ca38f31C74041B4F34128d281e5bE8,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xa23Ef637513Cd9B3AD28c3DA62a16CF63994Cc9b,
            37_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x9B7e8F6B5c0e434275cb90069434f00457493C7c,
            31_250_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x1B006a0318dF1cBcC072D1505F641796E0EA59B3,
            25_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x50319e5033010395C7da40f27C37Ed4BB2E92d6D,
            25_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x645149ff673C852458B0f1824c2daBcadc31Ca04,
            25_000_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xb5A257460769AA292CDcd3978C8242D9895a0B3D,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x73eF29632df2448dA4D4518135BdbcAA74B5F84f,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x12357c21d95eB08E2D9C9262Edf6e09306de801d,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xf3C01C5e422C71d530BF7D584D879555afe5531f,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xaE2cb8b8D1Ba8f4040078036fa63d6b792Fea7f0,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0xfD98e88b9FD2eC6275403A2c5a8461fccaa044b3,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x40E285282f239ca11522954d3d30d0371733762B,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x9Ecc3F82726950D0c62d96A1C7576731E2D187db,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x2899bbE9cbb7285b345Dc0AD40C39CB2AF3a7C5C,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x4B34C734CE125c354F8dD4e457C85bF3DF1890d9,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x566CAd1FBA28aC265f046579261695D4c9F6d4da,
            18_750_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x6A25138B5AD1ba8189db063663E484AF4ecBb991,
            12_500_000,
            FOUR_YEARS,
            jan01_2024
        );
        _pushAllocation(
            true,
            0x9187B358582769D5e310b0f2709583795E8327dB,
            12_500_000,
            FOUR_YEARS,
            jan01_2024
        );
    }

    function _pushAllocation(
        bool _unlock20Percent,
        address _stakeOwner,
        uint256 _stakeAmount,
        uint256 _lockingTime,
        uint256 _initialTime
    )
        internal
    {
        allocations.push(
            Allocation({
                unlock20Percent: _unlock20Percent,
                stakeOwner: _stakeOwner,
                stakeAmount: _stakeAmount,
                lockingTime: _lockingTime,
                initialTime: _initialTime
            })
        );

        initialTokensRequired += _stakeAmount;
        expectedUniqueAmounts[_stakeAmount] -= 1;
        expectedInitialAmount[_stakeOwner] = _stakeAmount;
    }

    function _pushUniqueAmount(
        uint256 _amount,
        uint256 _count
    )
        internal
    {
        uniqueAmounts.push(
            UniqueAmount({
                amount: _amount,
                count: _count
            })
        );
    }

    function _setupAmounts()
        internal
    {
        _pushUniqueAmount(
            312_500_000,
            2
        );
        _pushUniqueAmount(
            262_500_000,
            2
        );
        _pushUniqueAmount(
            187_500_000,
            2
        );
        _pushUniqueAmount(
            162_500_000,
            1
        );
        _pushUniqueAmount(
            137_500_000,
            2
        );
        _pushUniqueAmount(
            125_000_000,
            1
        );
        _pushUniqueAmount(
            112_500_000,
            2
        );
        _pushUniqueAmount(
            100_000_000,
            1
        );
        _pushUniqueAmount(
            87_500_000,
            29
        );
        _pushUniqueAmount(
            75_000_000,
            3
        );
        _pushUniqueAmount(
            62_500_000,
            5
        );
        _pushUniqueAmount(
            56_250_000,
            3
        );
        _pushUniqueAmount(
            50_000_000,
            2
        );
        _pushUniqueAmount(
            37_500_000,
            8
        );
        _pushUniqueAmount(
            31_250_000,
            1
        );
        _pushUniqueAmount(
            25_000_000,
            3
        );
        _pushUniqueAmount(
            18_750_000,
            11
        );
        _pushUniqueAmount(
            12_500_000,
            2
        );
        for (uint256 i = 0; i < uniqueAmounts.length; i++) {
            UniqueAmount memory uniqueAmount = uniqueAmounts[i];
            expectedUniqueAmounts[
                uniqueAmount.amount
            ] = uniqueAmount.count;
        }
    }
}
