// SPDX-License-Identifier: -- BCOM --

pragma solidity =0.8.23;

struct Allocation {
    bool unlock20Percent;
    address stakeOwner;
    uint256 stakeAmount;
    uint256 vestingTime;
}

contract ManagerHelper {

    Allocation[] public allocations;

    uint256 public constant EXPECTED_ALLOCATIONS = 89;
    uint256 public constant EXPECTED_TOTAL_TOKENS = 100_000_000 * 1E18;

    function _setupAllocations()
        internal
    {
        uint256 fourYears = 365 days * 4;

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x01b7b155f4934d52AAb625E8F7f20F81f78211Aa,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x2062C4515f7DF5B0D71A3450e5cD5574b507ba3a,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x636EE9dd1a3F9b85A78b8c08c1E5A8506703fc8A,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x7F7BadeE622D6d1aB597Cfcbf549F4E8c44c384E,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x97123BD90Ecb6D807E61fae5019C6A608E008542,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x9Ecc3F82726950D0c62d96A1C7576731E2D187db,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0xA49105aa03810Df66e44AeaD21ccbE908C98BE2E,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0xAda591ecBD9EDb88A8CB0270417D5D77C2f944C7,
                stakeAmount: 6_250_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: false,
                stakeOwner: 0x7E3d94b6396C659e653F48859118CD2e735c6955,
                stakeAmount: 6_250_000,
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
                stakeOwner: 0x5F09C1D7d28F34FdD3a5492Cde34c74cB4875095,
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
                stakeOwner: 0x641AD78BAca220C5BD28b51Ce8e0F495e85Fe689,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x680783fad0137725B06fBf2929565B38350A26E4,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x6A25138B5AD1ba8189db063663E484AF4ecBb991,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x73eF29632df2448dA4D4518135BdbcAA74B5F84f,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x74c363e7577A6B3830B5025f60204d686ED2D5af,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x79Db74988EAb4b9Add9d41239a06FAe4b2820E61,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x7fae227057989C9bC0afAeCFEf18Bc68a6e03161,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x81cDC1123382Ce7cc890D7D3D86bD3Da6EDCE78e,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x82bCf2FceBBb6ba19d835c7397403b3922E74cb4,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x82C66CB5D6c6260979e604CeedA85635C74A175F,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x9187B358582769D5e310b0f2709583795E8327dB,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x9B7e8F6B5c0e434275cb90069434f00457493C7c,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xa23Ef637513Cd9B3AD28c3DA62a16CF63994Cc9b,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xA5297Ac98A98Bc4E4c929137E04747DEF6830e66,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xAd7741919812Fdae1cBB773A62613f3eb2C814d0,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xaE2cb8b8D1Ba8f4040078036fa63d6b792Fea7f0,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xb5A257460769AA292CDcd3978C8242D9895a0B3D,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xbA66e7784c83340F521553665F06e252452502C2,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xbeB16AE9233cb2dA0cA985f45a0b72d99078fCC4,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xcb0d66a021463A4FD198290b53a8Bf3d1F58225b,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xd2281942Ec5231c71402954F823Cdb8Fad721327,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xd360c96496eBF32cF0C71d568c3E95dfcB5cB704,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xdd9f62286433620a3884bF7614026371A4fA598E,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xE1EfC068A1Ca38f31C74041B4F34128d281e5bE8,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xe2f858dBAC42a955f466c13ae20c664bDD1eFA6F,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xE33C392d324332B34a5447C1f228Db557D68C180,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xe4a7F8d63d7211B8081D7c65C9e66188873FD113,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xe4CC1d1bBf5819F158ab0d0f65378AD9eD9bBC80,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xE730A2803064Dd21915D436FE082C2e78e49590d,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xea279533BA1458D55E29306E50c8939C2541Def3,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xF33Ec3e5D76aA39504aa37548Bb7c0Cee9Bb45e0,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xF7386F84dfA7b3ddA8c1790417F98713C7e03dF8,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xFf98222E3de88539A2496ed0AabB719AD00E2472,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x127564F78d371ECcE6Ab86A179Be4e4378B6ea3D,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x28484c3Bb9F10ac262A67041a273552BeEd7C661,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xE41b1aD07b9Ab7c8a28a8e491a76890eD6fB619b,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x38Ec5897860Dfa500D20D8B8E16159f821031128,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xACa5d2a508d542DAaE3e340507D985A465c0E1a3,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x1356ee38f20500F6176c45A3D42525fec5A986b5,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xc69BCD45002514435E1525A5a1ad606e28572bbC,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xa46Cb95414f1a3952f5A9F1d6561084E27279EB3,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x69EBe456568948713CB6761D220a5c58E1315F39,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x6db4F972AAA59DF869FD643925450211Acb097D5,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x6fEeB0c3E25E5dEf17BC7274406F0674B8237038,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x2899bbE9cbb7285b345Dc0AD40C39CB2AF3a7C5C,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x6c6bc62D7fF556f802810810bFDEEB01A1aFdbDf,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x5c82AC87A41E7627EB9a43Cc584b5441C376D916,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xa474d76e79586A1179B825B5ED46d61Ee2183e3C,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x185254e29FC8A95C16f982bE061Cc5aeb5b94231,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x606c633B612769B896be4BACC35c55973fDa7Bf7,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x8aAfCb8a08E62f5902A468B98F0C519B2E0dFF50,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xDb265a7ED888498C4416CfE1DEEd58cf7eFFdFDc,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x8f4038F0B0FDfc8E8621e1e5a8Bcd951b0FB8Bc9,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xfD98e88b9FD2eC6275403A2c5a8461fccaa044b3,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x4B34C734CE125c354F8dD4e457C85bF3DF1890d9,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xf3C01C5e422C71d530BF7D584D879555afe5531f,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x40E285282f239ca11522954d3d30d0371733762B,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x6D11be994Ea09E49705E480D836e2E887f041C3D,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0xb76296e5db55E30a94ae61A857A0e5DF40c86ef8,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x5cEDbA76c3987604c8c348E9accB9ca00d24F623,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x35e52181568f9245E6C040cB587970984369e104 ,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );

        allocations.push(
            Allocation({
                unlock20Percent: true,
                stakeOwner: 0x645149ff673C852458B0f1824c2daBcadc31Ca04,
                stakeAmount: 12_500_000,
                vestingTime: fourYears
            })
        );
    }
}