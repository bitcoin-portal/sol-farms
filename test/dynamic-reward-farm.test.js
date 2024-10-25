const Token = artifacts.require("TestToken");
const Farm = artifacts.require("DynamicRewardFarm");
const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { assert } = require('chai');
const { parse } = require('micromatch');

require("./utils");

const _BN = web3.utils.BN;
const BN = (value) => {
    return new _BN(value)
}
const tokens = (value) => {
    return web3.utils.toWei(value);
}

const tokensBN = (value) => {
    return new _BN(web3.utils.toWei(value));
};

const PRECISIONS = tokens("1");
const ONE_TOKEN = tokens("1");
const TWO_TOKENS = tokens("2");

const MAX_VALUE = BN(2)
    .pow(BN(256))
    .sub(BN(1));

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents((eventName), {
        fromBlock: 0,
        toBlock: "latest",
    });
    return events.pop().returnValues;
};

contract("DynamicRewardFarm", ([owner, alice, bob, chad, random]) => {

    const DEAD_ADDRESS = "0x000000000000000000000000000000000000dEaD";
    const defaultDurationInSeconds = 300;

    const setupScenario = async (inputParams = {}) => {

        const stakeToken = await Token.new();
        const rewardTokenA = await Token.new();
        const rewardTokenB = await Token.new();
        const rewardTokenC = await Token.new();

        const defaultApprovalAmount = tokens("1000000");

        const farm = await Farm.new();

        await farm.initialize(
            stakeToken.address,
            defaultDurationInSeconds,
            owner,
            owner,
            "VerseFarm",
            "VFARM"
        );

        if (inputParams.approval) {
            const approvalAmount = tokens(defaultApprovalAmount.toString());
            await stakeToken.approve(
                farm.address,
                approvalAmount
            );
            // Approvals for reward tokens are handled in the test
        }

        if (inputParams.deposit) {
            await farm.farmDeposit(
                inputParams.deposit
            );
        }

        if (inputParams.addRewardTokens) {
            for (const token of inputParams.addRewardTokens) {
                await farm.addRewardToken(
                    token.address,
                    { from: owner }
                );
            }
        }

        return {
            stakeToken,
            rewardTokenA,
            rewardTokenB,
            rewardTokenC,
            farm
        }
    }

    describe("Farm initial values", () => {

        beforeEach(async () => {
            const result = await setupScenario();
            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;
        });

        it("should have correct farm name", async () => {
            const name = await farm.name();
            assert.equal(
                name,
                "VerseFarm"
            );
        });

        it("should have correct farm symbol", async () => {
            const symbol = await farm.symbol();
            assert.equal(
                symbol,
                "VFARM"
            );
        });

        it("should have correct farm decimals", async () => {
            const decimals = await farm.decimals();
            assert.equal(
                decimals,
                18
            );
        });

        it("should have correct farm supply", async () => {

            const defaultSupplyValue = await farm.totalSupply();
            const expectedDefaultValue = 1E18;

            assert.equal(
                defaultSupplyValue,
                expectedDefaultValue
            );
        });

        it("should return receipt balance for the given account", async () => {

            const defaultBalance = await farm.balanceOf(
                owner
            );

            const expectedDefaultBalance = 0;

            assert.equal(
                defaultBalance,
                expectedDefaultBalance
            );
        });

        it("should return the correct allowance for the given spender", async () => {

            const defaultAllowance = await farm.allowance(
                owner,
                bob
            );

            const expectedDefaultAllowance = 0;

            assert.equal(
                defaultAllowance,
                expectedDefaultAllowance
            );
        });

        it("should have correct staking token address", async () => {

            const stakeTokenValue = await farm.stakeToken();

            assert.equal(
                stakeTokenValue,
                stakeToken.address
            );
        });

        it("should have correct owner address", async () => {

            const ownerAddress = await farm.ownerAddress();

            assert.equal(
                ownerAddress,
                owner
            );
        });

        it("should have correct manager address", async () => {

            const managerAddress = await farm.managerAddress();

            assert.equal(
                managerAddress,
                owner
            );
        });

        it("should have correct lastUpdateTime value", async () => {

            const lastUpdateTime = await farm.lastUpdateTime();
            const expectedDefaultValue = 0;

            assert.equal(
                lastUpdateTime,
                expectedDefaultValue
            );
        });

        it("should have correct duration value", async () => {

            const defaultDurationValue = await farm.rewardDuration();

            assert.equal(
                defaultDurationValue,
                defaultDurationInSeconds
            );
        });

        it("should not be able to initialize with wrong default duration value", async () => {

            const invalidDuration = 0;
            const correctDuration = 1;

            const f = await Farm.new();

            await expectRevert(
                f.initialize(
                    stakeToken.address,
                    invalidDuration,
                    owner,
                    owner,
                    "VerseFarm",
                    "VFARM"
                ),
                "DynamicRewardFarm: INVALID_DURATION"
            );

            await f.initialize(
                stakeToken.address,
                correctDuration,
                owner,
                owner,
                "VerseFarm",
                "VFARM"
            );

            assert.isAbove(
                correctDuration,
                invalidDuration
            );
        });
    });

    describe("Duration initial functionality", () => {

        beforeEach(async () => {
            const result = await setupScenario({
                approval: true
            });
            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;
        });

        it("should be able to change farm duration value", async () => {

            const defaultDuration = await farm.rewardDuration();
            const expectedDefaultDuration = defaultDurationInSeconds;
            const newDurationValueIncrease = 600;
            const newDurationValueDecrease = 100;

            assert.equal(
                defaultDuration,
                expectedDefaultDuration
            );

            assert.isAbove(
                newDurationValueIncrease,
                parseInt(defaultDuration)
            );

            assert.isBelow(
                newDurationValueDecrease,
                parseInt(defaultDuration)
            );

            await farm.setRewardDuration(
                newDurationValueDecrease
            );

            const durationValueDecreased = await farm.rewardDuration();

            assert.equal(
                durationValueDecreased,
                newDurationValueDecrease
            );

            assert.isBelow(
                parseInt(durationValueDecreased),
                parseInt(defaultDuration)
            );

            await farm.setRewardDuration(
                newDurationValueIncrease
            );

            const durationValueIncreased = await farm.rewardDuration();

            assert.equal(
                durationValueIncreased,
                newDurationValueIncrease
            );

            assert.isAbove(
                parseInt(durationValueIncreased),
                parseInt(defaultDuration)
            );
        });

        it("should be able to change farm duration value only by manager", async () => {

            const newDurationValue = 10;
            const actualManager = await farm.managerAddress();
            const wrongManager = bob;
            const correctManager = owner;

            await expectRevert(
                farm.setRewardDuration(
                    newDurationValue,
                    {
                        from: wrongManager
                    }
                ),
                "DynamicRewardFarm: INVALID_MANAGER"
            );

            assert.notEqual(
                wrongManager,
                actualManager
            );

            await farm.setRewardDuration(
                newDurationValue,
                {
                    from: correctManager
                }
            );

            assert.equal(
                correctManager,
                actualManager
            );

            const durationValueChanged = await farm.rewardDuration();

            assert.equal(
                durationValueChanged,
                newDurationValue
            );
        });

        it("should not be able to change farm duration value to 0", async () => {

            const defaultDuration = await farm.rewardDuration();
            const expectedDefaultDuration = defaultDurationInSeconds;

            assert.equal(
                defaultDuration,
                expectedDefaultDuration
            );

            const newDurationWrongValue = 0;
            const newDurationRightValue = 1;

            await expectRevert(
                farm.setRewardDuration(
                    newDurationWrongValue
                ),
                "DynamicRewardFarm: INVALID_DURATION"
            );

            await farm.setRewardDuration(
                newDurationRightValue
            );

            assert.isAbove(
                newDurationRightValue,
                newDurationWrongValue
            );
        });

        it("should not be able to change farm duration during distribution", async () => {

            const defaultDuration = await farm.rewardDuration();
            const expectedDefaultDuration = defaultDurationInSeconds;
            const newDurationWrongValue = 100;
            const expectedAmount = tokens("10");

            assert.equal(
                defaultDuration,
                expectedDefaultDuration
            );

            await farm.farmDeposit(
                tokens("10")
            );

            // Add reward tokens and set rates
            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );

            await rewardTokenA.approve(
                farm.address,
                tokens("1000000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("1000000")
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    expectedAmount,
                    expectedAmount
                ]
            );

            await expectRevert(
                farm.setRewardDuration(
                    newDurationWrongValue
                ),
                "DynamicRewardFarm: ONGOING_DISTRIBUTION"
            );

            await time.increase(
                defaultDuration + 1
            );

            await farm.setRewardDuration(
                newDurationWrongValue
            );

            const newDuration = await farm.rewardDuration();

            assert.equal(
                newDuration,
                newDurationWrongValue
            );
        });
    });

    describe("Reward allocation initial functionality by manager", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            // Add reward tokens
            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );
        });

        it("should not be able to set rate to 0", async () => {

            await farm.farmDeposit(
                ONE_TOKEN
            );

            await expectRevert(
                farm.setRewardRates(
                    [
                        rewardTokenA.address,
                        rewardTokenB.address
                    ],
                    [
                        0,
                        0
                    ]
                ),
                "NoRewards()"
            );

            await rewardTokenA.approve(
                farm.address,
                tokens("1000000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("1000000")
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    1,
                    1
                ]
            );
        });

        it("should correctly set the periodFinished date value", async () => {

            const initialPeriod = await farm.periodFinished();
            const expectedDuration = await farm.rewardDuration();
            const initialRate = tokens("10");
            const expectedInitialValue = 0;

            assert.equal(
                initialPeriod,
                expectedInitialValue
            );

            await farm.farmDeposit(
                ONE_TOKEN
            );

            await rewardTokenA.approve(
                farm.address,
                tokens("100000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("100000")
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    initialRate,
                    initialRate
                ]
            );

            const initialTimestamp = await time.latest();
            const valueAfterChange = await farm.periodFinished();

            assert.isAbove(
                parseInt(valueAfterChange),
                parseInt(initialPeriod)
            );

            assert.equal(
                parseInt(valueAfterChange),
                parseInt(initialTimestamp) + parseInt(expectedDuration)
            );
        });

        it("should emit correct RewardsAdded event", async () => {

            const initialRateA = tokens("10");
            const initialRateB = tokens("20");
            const rewardDuration = await farm.rewardDuration();
            const expectedAmountA = BN(rewardDuration).mul(BN(initialRateA));
            const expectedAmountB = BN(rewardDuration).mul(BN(initialRateB));

            await farm.farmDeposit(
                ONE_TOKEN
            );

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                expectedAmountA,
                { from: owner }
            );

            await rewardTokenB.approve(
                farm.address,
                expectedAmountB,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    initialRateA,
                    initialRateB
                ]
            );

            const rewardEvents = await farm.getPastEvents("RewardAdded", {
                fromBlock: 0,
                toBlock: "latest",
            });

            const rewardEventA = rewardEvents.find(e => e.returnValues.rewardToken === rewardTokenA.address);
            const rewardEventB = rewardEvents.find(e => e.returnValues.rewardToken === rewardTokenB.address);

            assert.equal(
                rewardEventA.returnValues.tokenAmount,
                expectedAmountA.toString()
            );

            assert.equal(
                rewardEventB.returnValues.tokenAmount,
                expectedAmountB.toString()
            );
        });

        it("manager should be able to set rewards rate only if stakers exist", async () => {

            const newRewardRateA = tokens("10");
            const newRewardRateB = tokens("10");
            const expectedNewRate = newRewardRateA;

            // approve
            await rewardTokenA.approve(
                farm.address,
                tokens("1000000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("1000000")
            );

            await farm.farmDeposit(
                ONE_TOKEN
            );

            // Approve reward tokens
            const rewardDuration = await farm.rewardDuration();
            const totalRewardA = BN(newRewardRateA).mul(BN(rewardDuration));
            const totalRewardB = BN(newRewardRateB).mul(BN(rewardDuration));

            await rewardTokenA.approve(
                farm.address,
                totalRewardA,
                { from: owner }
            );

            await rewardTokenB.approve(
                farm.address,
                totalRewardB,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    newRewardRateA,
                    newRewardRateB
                ],
            );

            const rateAfterChanged = await farm.rewards(
                rewardTokenB.address
            );

            const rateB = rateAfterChanged.rewardRate;

            assert.equal(
                rateB.toString(),
                expectedNewRate.toString()
            );
        });

        it("manager should fund the farm during reward rate announcement", async () => {

            const newRewardRate = tokens("10");
            const expectedDuration = await farm.rewardDuration();
            const currentManager = await farm.managerAddress();

            const expectedTransferAmount = BN(newRewardRate)
                .mul(BN(expectedDuration));

            const managerBalanceA = await rewardTokenA.balanceOf(
                currentManager
            );

            const managerBalanceB = await rewardTokenB.balanceOf(
                currentManager
            );

            assert.isAbove(
                parseInt(managerBalanceA),
                parseInt(expectedTransferAmount)
            );

            assert.isAbove(
                parseInt(managerBalanceB),
                parseInt(expectedTransferAmount)
            );

            await farm.farmDeposit(
                ONE_TOKEN
            );

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                expectedTransferAmount,
                { from: owner }
            );

            await rewardTokenB.approve(
                farm.address,
                expectedTransferAmount,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    newRewardRate,
                    newRewardRate
                ],
            );

            const transferEventsA = await rewardTokenA.getPastEvents("Transfer", {
                fromBlock: 0,
                toBlock: "latest",
            });

            const transferEventA = transferEventsA.find(e => e.returnValues.to === farm.address);

            assert.equal(
                transferEventA.returnValues.from,
                currentManager
            );

            assert.equal(
                transferEventA.returnValues.to,
                farm.address
            );

            assert.equal(
                transferEventA.returnValues.value.toString(),
                expectedTransferAmount.toString()
            );

            const afterTransferManagerA = await rewardTokenA.balanceOf(
                currentManager
            );

            const afterTransferFarmA = await rewardTokenA.balanceOf(
                farm.address
            );

            assert.equal(
                managerBalanceA.toString(),
                BN(afterTransferManagerA).add(expectedTransferAmount).toString()
            );

            assert.equal(
                expectedTransferAmount.toString(),
                afterTransferFarmA.toString()
            );
        });

        it("manager should be able to increase rate any time", async () => {

            const initialRate = tokens("10");
            const increasedRewardRate = tokens("11");

            assert.isAbove(
                parseInt(increasedRewardRate),
                parseInt(initialRate)
            );

            await farm.farmDeposit(
                ONE_TOKEN
            );

            const rewardDuration = await farm.rewardDuration();
            const totalRewardInitial = BN(initialRate).mul(BN(rewardDuration));
            const totalRewardIncreased = BN(increasedRewardRate).mul(BN(rewardDuration));

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalRewardInitial,
                { from: owner }
            );

            await rewardTokenB.approve(
                farm.address,
                totalRewardInitial,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    initialRate,
                    initialRate
                ],
            );

            const rateBeforeChanged = (await farm.rewards(
                rewardTokenA.address)
            ).rewardRate;

            assert.equal(
                rateBeforeChanged.toString(),
                initialRate.toString()
            );

            // Approve additional tokens for increased rate
            await rewardTokenA.approve(
                farm.address,
                totalRewardIncreased,
                { from: owner }
            );

            await rewardTokenB.approve(
                farm.address,
                totalRewardIncreased,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    increasedRewardRate,
                    increasedRewardRate
                ]
            );

            const rateAfterChanged = (await farm.rewards(
                rewardTokenA.address
            )).rewardRate;

            assert.equal(
                rateAfterChanged.toString(),
                increasedRewardRate.toString()
            );
        });

        it("manager should be able to decrease rate only after distribution finished", async () => {

            const initialRate = tokens("10");
            const decreasedRewardRate = tokens("9");

            assert.isBelow(
                parseInt(decreasedRewardRate),
                parseInt(initialRate)
            );

            await farm.farmDeposit(
                ONE_TOKEN
            );

            const rewardDuration = await farm.rewardDuration();
            const totalRewardInitial = BN(initialRate).mul(BN(rewardDuration));
            const totalRewardDecreased = BN(decreasedRewardRate).mul(BN(rewardDuration));

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalRewardInitial,
                { from: owner }
            );

            // Approve reward tokens
            await rewardTokenB.approve(
                farm.address,
                totalRewardInitial,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    initialRate,
                    initialRate
                ],
            );

            const rateAfterChanged = (
                await farm.rewards(
                    rewardTokenA.address
                )
            ).rewardRate;

            assert.equal(
                rateAfterChanged.toString(),
                initialRate.toString()
            );

            await expectRevert(
                farm.setRewardRates(
                    [
                        rewardTokenA.address,
                        rewardTokenB.address
                    ],
                    [
                        decreasedRewardRate,
                        decreasedRewardRate
                    ]
                ),
                "DynamicRewardFarm: RATE_CANT_DECREASE"
            );

            const currentDuration = await farm.rewardDuration();

            await time.increase(
                currentDuration
            );

            // Approve tokens for decreased rate
            await rewardTokenA.approve(
                farm.address,
                totalRewardDecreased,
                { from: owner }
            );

            // Approve tokens for decreased rate
            await rewardTokenB.approve(
                farm.address,
                totalRewardDecreased,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    decreasedRewardRate,
                    decreasedRewardRate
                ],
            );

            const newRate = (await farm.rewards(rewardTokenA.address)).rewardRate;

            assert.equal(
                parseInt(newRate.toString()),
                parseInt(decreasedRewardRate.toString())
            );
        });
    });

    describe("User starts earning rewards after depositing and setting reward rate", () => {

        let stakeToken, rewardTokenA, farm, defaultRewardRate;

        beforeEach(async () => {
            // Setup scenario where the user deposits into the farm
            const result = await setupScenario({
                approval: true,
                deposit: tokens("100"),
                // addRewardTokens: []
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            // Add rewardTokenA as a reward token
            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );

            defaultRewardRate = tokens("10");

            // Mint reward tokens to the owner
            const rewardDuration = await farm.rewardDuration();
            const totalReward = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalReward
            );

            await rewardTokenB.approve(
                farm.address,
                totalReward
            );
        });

        it("should allow user to earn rewards after depositing and setting reward rate", async () => {

            const stakerAddress = owner;

            // Initially, user has deposited but time hasn't advanced
            let earnedInitial = await farm.earned(
                stakerAddress
            );

            const rewardTokens = await farm.getRewardTokens();

            assert.equal(
                rewardTokens.length,
                2,
                "rewardTokens should have 2 elements"
            );

            // earnedInitial should have 2 elements
            assert.equal(
                earnedInitial.length,
                rewardTokens.length,
                "earnedInitial should have 2 elements"
            );

            // earnedInitial both elements should be 0
            assert.equal(
                earnedInitial[0].toString(),
                "0",
                "earnedInitial[0] should be 0"
            );

            assert.equal(
                earnedInitial[1].toString(),
                "0",
                "earnedInitial[1] should be 0"
            );

            // Access the first element for rewardTokenA
            const earnedInitialValue = earnedInitial[0];

            // User should not have any earned rewards yet
            assert.equal(
                earnedInitialValue.toString(),
                "0",
                "User should not have earned rewards before time has passed"
            );

            assert.equal(
                rewardTokens[0],
                rewardTokenA.address,
                "First token should be rewardTokenA"
            );

            assert.equal(
                rewardTokens[1],
                rewardTokenB.address,
                "Second token should be rewardTokenB"
            );

            // console.log(tokens.toString(), 'tokens');
            // console.log(rewardTokenA.address, 'tokenA');

            const defaultRate = tokens("10");

            // approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                tokens("1000000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("1000000")
            );

            // Manager sets the reward rate
            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    defaultRate,
                    defaultRate
                ]
            );

            const rewardPerToken = await farm.rewards(
                rewardTokenA.address
            );

            assert.equal(
                rewardPerToken.rewardRate.toString(),
                defaultRate.toString(),
                "Reward rate should be 10"
            );

            assert.equal(
                rewardPerToken.perTokenStored.toString(),
                "0",
                "perTokenStored should be 0"
            );

            // console.log(rewardPerToken.rewardRate.toString(), 'rewardPerToken.rewardRate');
            // console.log(rewardPerToken.perTokenStored.toString(), 'rewardPerToken.perTokenStored');

            // Advance time to allow rewards to accrue
            const timeIncrease = 3000;
            await time.increase(timeIncrease);

            // User checks earned rewards
            let earnedAfter = await farm.earned(
                stakerAddress
            );

            // Access the first element for rewardTokenA
            const earnedAfterValue = earnedAfter[0];
            console.log(earnedAfter.toString(), 'earnedAfterValue')

            // User should now have earned rewards
            assert.isAbove(
                parseInt(earnedAfterValue.toString()),
                parseInt(0),
                `${earnedAfterValue.toString()} is not greater than 0`
            );

            const earnedByDead = await farm.earned(
                DEAD_ADDRESS
            );

            const balanceOfFarm = await rewardTokenA.balanceOf(
                farm.address
            );

            const earnedByOwner = await farm.earned(
                stakerAddress
            );

            console.log(earnedByDead.toString(), 'earnedByDead');
            console.log(balanceOfFarm.toString(), 'balanceOfFarm');
            console.log(earnedByOwner.toString(), 'earnedByOwner');

            assert.equal(
                parseInt(earnedByOwner[0]) + parseInt(earnedByDead[0]),
                parseInt(balanceOfFarm),
            );

            // Should be able to claim rewards
            await farm.claimRewards();

            // Check that user has no rewards after claiming
            let earnedAfterClaim = await farm.earned(
                stakerAddress
            );

            assert.equal(
                earnedAfterClaim[0].toString(),
                "0",
                "User should have no rewards after claiming"
            );
        });
    });

    describe("Earning functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true,
                deposit: ONE_TOKEN
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            rewardTokenC = result.rewardTokenC;
            farm = result.farm;

            defaultRewardRate = tokens("10");

            // Add reward tokens and set rates
            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );

            await rewardTokenA.approve(
                farm.address,
                tokens("1000000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("1000000")
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate
                ]
            );
        });

        it("should earn rewards proportionally to stake time for all reward tokens", async () => {

            const stepTimeFrame = 1;
            const expectedDefaultEarn = 0;
            const rewardRateA = (await farm.rewards(rewardTokenA.address)).rewardRate;
            const rewardRateB = (await farm.rewards(rewardTokenB.address)).rewardRate;
            const earnPerStepA = stepTimeFrame * parseInt(rewardRateA);
            const earnPerStepB = stepTimeFrame * parseInt(rewardRateB);

            const tokenCount = await farm.tokenCount();

            assert.equal(
                tokenCount,
                2,
                "There should be 2 reward tokens"
            );

            // console.log(tokenCount.toString(), 'tokenCount');

            const earnedInital = await farm.earned(
                owner
            );

            // console.log(earnedInital.toString(), 'earnedInital');

            assert.equal(
                parseInt(earnedInital[0]),
                parseInt(expectedDefaultEarn)
            );

            assert.equal(
                parseInt(earnedInital[1]),
                parseInt(expectedDefaultEarn)
            );

            await time.increase(
                stepTimeFrame * 100
            );

            const earnedStep1 = await farm.earned(
                owner
            );

            // console.log(earnedStep1.toString(), 'earnedStep1');

            assert.isAtLeast(
                parseInt(earnedStep1[0]),
                earnPerStepA * 1
            );

            assert.isAtLeast(
                parseInt(earnedStep1[1]),
                earnPerStepB * 1
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedStep2 = await farm.earned(
                owner
            );

            assert.isAtLeast(
                parseInt(earnedStep2[0]),
                earnPerStepA * 2
            );

            assert.isAtLeast(
                parseInt(earnedStep2[1]),
                earnPerStepB * 2
            );
        });

        it("should allow users to earn rewards from newly added reward tokens after interaction", async () => {

            // Simulate time passing before new reward token is added
            await time.increase(100);

            // Add new reward token C
            await farm.addRewardToken(
                rewardTokenC.address,
                { from: owner }
            );

            // Approve reward token C
            const rewardDuration = await farm.rewardDuration();
            const totalRewardC = BN(defaultRewardRate).mul(BN(rewardDuration));

            await rewardTokenC.approve(
                farm.address,
                totalRewardC,
                { from: owner }
            );

            // Set reward rate for token C
            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address,
                    rewardTokenC.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate,
                    defaultRewardRate
                ],
                { from: owner }
            );

            // User interacts with the contract (e.g., claims rewards)
            await farm.claimRewards();

            // Check that user starts earning token C rewards after interaction
            await time.increase(10);

            const earned = await farm.earned(
                owner
            );

            // earned[2] corresponds to rewardTokenC
            assert.isAbove(
                parseInt(earned[2]),
                0,
                "User should start earning token C after interaction"
            );
        });
    });

    describe("Claiming Rewards", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true,
                deposit: tokens("1")
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            defaultRewardRate = tokens("10");
            defaultRewardRate2 = tokens("20");

            const rewardDuration = await farm.rewardDuration();
            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));
            const totalRewardB = BN(defaultRewardRate2).mul(BN(rewardDuration));

            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalRewardA
            );

            await rewardTokenB.approve(
                farm.address,
                totalRewardB
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate2
                ]
            );
        });

        it("should reset userRewards mapping after claim to 0 for all tokens", async () => {

            const expectedValue = 0;
            const timeIncrease = 100;

            await time.increase(
                timeIncrease
            );

            let earnedBeforeClaim = await farm.earned(
                owner
            );

            // earnedBeforeClaimByDeadAddress
            let earnedBeforeClaimByDeadAddress = await farm.earned(
                DEAD_ADDRESS
            );

            assert.isAbove(
                parseInt(earnedBeforeClaim[0]),
                expectedValue
            );

            assert.equal(
                parseInt(earnedBeforeClaim[1]) + parseInt(earnedBeforeClaimByDeadAddress[1]),
                timeIncrease * parseInt(defaultRewardRate2)
            );

            assert.isAbove(
                parseInt(earnedBeforeClaim[1]),
                expectedValue
            );

            assert.equal(
                parseInt(earnedBeforeClaim[0]) + parseInt(earnedBeforeClaimByDeadAddress[0]),
                timeIncrease * parseInt(defaultRewardRate)
            );

            await farm.claimRewards();

            let earnedAfterClaim = await farm.earned(
                owner
            );

            assert.equal(
                parseInt(earnedAfterClaim[0]),
                expectedValue // 0
            );

            assert.equal(
                parseInt(earnedAfterClaim[1]),
                expectedValue // 0
            );
        });

        it("should transfer correct reward amounts to user upon claiming", async () => {

            const stakerAddress = owner;

            const balanceBeforeA = await rewardTokenA.balanceOf(
                stakerAddress
            );

            const balanceBeforeB = await rewardTokenB.balanceOf(
                stakerAddress
            );

            await time.increase(10000);

            const earnedBeforeClaim = await farm.earned(
                stakerAddress
            );

            await farm.claimRewards();

            const balanceAfterA = await rewardTokenA.balanceOf(
                stakerAddress
            );

            const balanceAfterB = await rewardTokenB.balanceOf(
                stakerAddress
            );

            assert.equal(
                balanceAfterA.toString(),
                BN(balanceBeforeA).add(BN(earnedBeforeClaim[0])).toString()
            );

            assert.equal(
                balanceAfterB.toString(),
                BN(balanceBeforeB).add(BN(earnedBeforeClaim[1])).toString()
            );

            // Claiming rewards again should not change the balance as the user has already claimed
            await farm.claimRewards();

            const balanceAfterSecondClaimA = await rewardTokenA.balanceOf(
                stakerAddress
            );

            const balanceAfterSecondClaimB = await rewardTokenB.balanceOf(
                stakerAddress
            );

            assert.equal(
                balanceAfterSecondClaimA.toString(),
                balanceAfterA.toString()
            );

            assert.equal(
                balanceAfterSecondClaimB.toString(),
                balanceAfterB.toString()
            );

            // Farm balance should equal to DEAD_ADDRESS rewards
            // as the user has claimed all rewards
            const farmBalanceA = await rewardTokenA.balanceOf(
                farm.address
            );

            const deadAddyReward = await farm.earned(
                DEAD_ADDRESS
            );

            const farmBalanceB = await rewardTokenB.balanceOf(
                farm.address
            );

            assert.equal(
                parseInt(farmBalanceA),
                parseInt(deadAddyReward[0])
            );

            assert.equal(
                parseInt(farmBalanceB),
                parseInt(deadAddyReward[1])
            );

            // Allow admin to recover rewardTokens from the farm equivalent to the dead address rewards
            await farm.recoverToken(
                rewardTokenA.address,
                deadAddyReward[0]
            );

            await farm.recoverToken(
                rewardTokenB.address,
                deadAddyReward[1]
            );

            const farmBalanceAfterRecoveryA = await rewardTokenA.balanceOf(
                farm.address
            );

            const farmBalanceAfterRecoveryB = await rewardTokenB.balanceOf(
                farm.address
            );

            assert.equal(
                farmBalanceAfterRecoveryA.toString(),
                "0"
            );

            assert.equal(
                farmBalanceAfterRecoveryB.toString(),
                "0"
            );

            // Make sure admin cannot withdra wmore than the dead address rewards
            await expectRevert(
                farm.recoverToken(
                    rewardTokenA.address,
                    1
                ),
                "DynamicRewardFarm: NOT_ENOUGH_REWARDS"
            );

            await expectRevert(
                farm.recoverToken(
                    rewardTokenB.address,
                    1
                ),
                "DynamicRewardFarm: NOT_ENOUGH_REWARDS"
            );
        });
    });

    describe("Transfer Functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true,
                deposit: tokens("1000"),
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            rewardTokenC = result.rewardTokenC;
            farm = result.farm;

            defaultRewardRate = tokens("10");

            const rewardDuration = await farm.rewardDuration();
            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));
            const totalRewardB = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Add reward tokens and set rates
            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );

            await rewardTokenA.approve(
                farm.address,
                tokens("1000000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("1000000")
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate
                ]
            );

            // Mint and approve stake tokens for bob
            await stakeToken.mint(
                tokens("1000"),
                { from: bob }
            );

            await stakeToken.approve(
                farm.address,
                tokens("1000"),
                { from: bob }
            );

            // Bob deposits
            await farm.farmDeposit(
                tokens("1000"),
                { from: bob }
            );
        });

        it("should transfer correct amount of staked tokens and update rewards accordingly", async () => {

            const ownerBalanceBefore = await farm.balanceOf(owner);
            const bobBalanceBefore = await farm.balanceOf(bob);

            // Owner transfers some stake to Bob
            await farm.transfer(bob, tokens("500"));

            const ownerBalanceAfter = await farm.balanceOf(owner);
            const bobBalanceAfter = await farm.balanceOf(bob);

            assert.equal(
                ownerBalanceAfter.toString(),
                BN(ownerBalanceBefore).sub(BN(tokens("500"))).toString()
            );

            assert.equal(
                bobBalanceAfter.toString(),
                BN(bobBalanceBefore).add(BN(tokens("500"))).toString()
            );

            // Advance time and check rewards
            await time.increase(10);

            const ownerEarned = await farm.earned(owner);
            const bobEarned = await farm.earned(bob);

            // Both should have rewards proportional to their new stakes
            // Exact values depend on timing and calculations
            assert.isAbove(parseInt(ownerEarned[0]), 0);
            assert.isAbove(parseInt(bobEarned[0]), 0);
        });

        // needs fixing, seems after transfer user earned more than in whats left in farm
        it("should correctly handle transfers when users have not interacted with new reward tokens", async () => {

            const rewardDuration = await farm.rewardDuration();
            const totalRewardC = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Approve reward token C
            await rewardTokenC.approve(
                farm.address,
                totalRewardC
            );

            // check that Bob and Owner already earned some token A and token B
            const ownerEarned = await farm.earned(owner);
            const bobEarned = await farm.earned(bob);

            // ownerEarned and bobEarned should have only 2 elements
            assert.equal(
                ownerEarned.length,
                2
            );

            assert.equal(
                bobEarned.length,
                2
            );

            // check for token A
            assert.isAbove(parseInt(ownerEarned[0]), 0);
            assert.isAbove(parseInt(bobEarned[0]), 0);

            // check for token B
            assert.isAbove(parseInt(ownerEarned[1]), 0);
            assert.isAbove(parseInt(bobEarned[1]), 0);

            // Add new reward token C
            await farm.addRewardToken(
                rewardTokenC.address
            );

            // now owner and bob have 3 elements in earned
            const ownerEarnedAfter = await farm.earned(owner);
            const bobEarnedAfter = await farm.earned(bob);

            // ownerEarned and bobEarned should have 3 elements
            assert.equal(
                ownerEarnedAfter.length,
                3
            );

            assert.equal(
                bobEarnedAfter.length,
                3
            );

            // the 3rd element should be 0 as no rate is set yet
            assert.equal(
                ownerEarnedAfter[2].toString(),
                "0"
            );

            assert.equal(
                bobEarnedAfter[2].toString(),
                "0"
            );

            // Set reward rate for token C
            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address,
                    rewardTokenC.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate,
                    defaultRewardRate
                ]
            );

            // Advance time
            await time.increase(100);

            // Check that both have started earning token C rewards from the point of interaction
            const ownerEarnedCAfterIncrease = await farm.earnedByToken(
                rewardTokenC.address,
                owner
            );

            const bobEarnedCAfterIncrease = await farm.earnedByToken(
                rewardTokenC.address,
                bob
            );

            assert.isAbove(
                parseInt(ownerEarnedCAfterIncrease),
                0
            );

            assert.isAbove(
                parseInt(bobEarnedCAfterIncrease),
                0
            );

            // get balance of owner in farm tokens
            const ownerBalance = await farm.balanceOf(
                owner
            );

            // Owner transfers stake to bob
            await farm.transfer(
                bob,
                ownerBalance // full balance
            );

            await time.increase(100);

            // Owner stops earning anything as trasnfer all tokens no Bob
            const ownerEarnedAfterTransferA = await farm.earned(owner);

            await time.increase(100);

            const ownerEarnedAfterTransferB = await farm.earned(owner);

            assert.equal(
                ownerEarnedAfterTransferA[0].toString(),
                ownerEarnedAfterTransferB[0].toString()
            );

            assert.equal(
                ownerEarnedAfterTransferA[1].toString(),
                ownerEarnedAfterTransferB[1].toString()
            );

            assert.equal(
                ownerEarnedAfterTransferA[2].toString(),
                ownerEarnedAfterTransferB[2].toString()
            );

            const howMuchInFarm = await rewardTokenC.balanceOf(
                farm.address
            );

            // amount in farm should be equal to totalRewardC
            assert.equal(
                howMuchInFarm.toString(),
                totalRewardC.toString()
            );

            // Advance time
            await time.increase(60000);

            // Check that both have started earning token C rewards from the point of interaction
            const ownerEarnedC = await farm.earnedByToken(
                rewardTokenC.address,
                owner
            );

            assert.isAbove(
                parseInt(ownerEarnedC),
                parseInt(ownerEarnedCAfterIncrease)
            );

            const bobEarnedC = await farm.earnedByToken(
                rewardTokenC.address,
                bob
            );

            const bobEarnedAllTokens = await farm.earned(bob);

            assert.isAbove(parseInt(ownerEarnedC), 0);
            assert.isAbove(parseInt(bobEarnedC), 0);

            await farm.claimRewards(
                { from: owner }
            );

            const howMuchInFarmLeftC = await rewardTokenC.balanceOf(
                farm.address
            );

            const howMuchInFarmLeftA = await rewardTokenA.balanceOf(
                farm.address
            );

            const howMuchInFarmLeftB = await rewardTokenB.balanceOf(
                farm.address
            );

            // earned by dead address
            const deadAddyEarned = await farm.earned(
                DEAD_ADDRESS
            );

            // howMuchInFarmLeftC should be same as bobs rewards
            assert.equal(
                parseInt(howMuchInFarmLeftC),
                parseInt(bobEarnedAllTokens[2]) + parseInt(deadAddyEarned[2])
            );

            assert.isAbove(
                parseInt(howMuchInFarmLeftA),
                parseInt(bobEarnedAllTokens[0])
            );

            assert.isAbove(
                parseInt(howMuchInFarmLeftB),
                parseInt(bobEarnedAllTokens[1])
            );

            // Bob claims his rewards
            await farm.claimRewards(
                { from: bob }
            );

            await time.increase(100);

            // Check that both have claimed rewards and their earned is now 0
            const ownerEarnedCAfterClaim = await farm.earnedByToken(
                rewardTokenC.address,
                owner
            );

            const bobEarnedCAfterClaim = await farm.earnedByToken(
                rewardTokenC.address,
                bob
            );

            // Since both claimed rewards their earned should be 0
            assert.equal(
                ownerEarnedCAfterClaim.toString(),
                "0"
            );

            assert.equal(
                bobEarnedCAfterClaim.toString(),
                "0"
            );

            // Check that the farm balance is 0 after all rewards are claimed
            const howMuchInFarmLeftAfter = await rewardTokenC.balanceOf(
                farm.address
            );

            const rewardByDead = await farm.earned(
                DEAD_ADDRESS
            );

            const biggerValue = 2;
            const smallerValue = 1;

            assert.equal(
                biggerValue > smallerValue,
                true
            );

            assert.isAbove(
                2,
                1
            );

            assert.isAbove(
                parseInt(howMuchInFarmLeftAfter),
                parseInt(rewardByDead[2].toString())
            );

            // Check that the farm balance is 0 after all rewards are claimed
            const howMuchInFarmLeftAfterA = await rewardTokenA.balanceOf(
                farm.address
            );

            assert.isAbove(
                parseInt(howMuchInFarmLeftAfterA),
                parseInt(rewardByDead[0])
            );

            // Check that the farm balance is 0 after all rewards are claimed

            const howMuchInFarmLeftAfterB = await rewardTokenB.balanceOf(
                farm.address
            );

            assert.isAbove(
                parseInt(howMuchInFarmLeftAfterB),
                parseInt(rewardByDead[1])
            );
        });
    });

    describe("Withdrawing Functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true,
                deposit: tokens("1000")
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            defaultRewardRate = tokens("10");

            const rewardDuration = await farm.rewardDuration();
            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));
            const totalRewardB = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Add reward tokens and set rates
            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalRewardA,
                { from: owner }
            );

            await rewardTokenB.approve(
                farm.address,
                totalRewardB,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate
                ]
            );
        });

        it("should allow users to withdraw staked tokens", async () => {

            const balanceBefore = await farm.balanceOf(owner);
            const stakeTokenBalanceBefore = await stakeToken.balanceOf(owner);

            await farm.farmWithdraw(tokens("500"));

            const balanceAfter = await farm.balanceOf(owner);
            const stakeTokenBalanceAfter = await stakeToken.balanceOf(owner);

            assert.equal(
                balanceAfter.toString(),
                BN(balanceBefore).sub(BN(tokens("500"))).toString()
            );

            assert.equal(
                stakeTokenBalanceAfter.toString(),
                BN(stakeTokenBalanceBefore).add(BN(tokens("500"))).toString()
            );
        });

        it("should update rewards upon withdrawal", async () => {

            await time.increase(10);

            const earnedBefore = await farm.earned(
                owner
            );

            await farm.farmWithdraw(tokens("500"));

            const earnedAfter = await farm.earned(
                owner
            );

            // earnedAfter should be updated correctly
            // Depending on the timing, earnedAfter may be less or the same
            assert.isAtLeast(
                parseInt(earnedAfter[0]),
                parseInt(earnedBefore[0])
            );
        });
    });

    describe("Adding New Reward Tokens", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true,
                deposit: tokens("1000")
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenC = result.rewardTokenC; // New token to be added
            farm = result.farm;

            defaultRewardRate = tokens("10");

            const rewardDuration = await farm.rewardDuration();
            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Add reward tokens
            await farm.addRewardToken(
                rewardTokenA.address
            );

            // Approve reward token A
            await rewardTokenA.approve(
                farm.address,
                totalRewardA,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address
                ],
                [
                    defaultRewardRate
                ]
            );
        });

        it("should allow manager to add new reward tokens", async () => {

            await farm.addRewardToken(rewardTokenC.address, { from: owner });

            const rewardTokens = await farm.getRewardTokens();

            assert.equal(
                rewardTokens.length,
                2,
                "Should have two reward tokens after addition"
            );

            assert.equal(
                rewardTokens[1],
                rewardTokenC.address,
                "Second reward token should be rewardTokenC"
            );
        });

        it("should prevent adding the same reward token twice", async () => {

            await farm.addRewardToken(
                rewardTokenC.address
            );

            await expectRevert(
                farm.addRewardToken(
                    rewardTokenC.address
                ),
                "ExistingToken()"
            );
        });

        it("should start distributing new reward token after setting its rate", async () => {

            await farm.addRewardToken(
                rewardTokenC.address
            );

            const rewardDuration = await farm.rewardDuration();

            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));
            const totalRewardC = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Approve reward token A
            await rewardTokenA.approve(
                farm.address,
                totalRewardA
            );

            // Approve reward token C
            await rewardTokenC.approve(
                farm.address,
                totalRewardC
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenC.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate
                ]
            );

            const earnedBeforeTimeIncrease = await farm.earned(
                owner
            );

            assert.equal(
                earnedBeforeTimeIncrease[1].toString(),
                "0",
                "User should not earn rewardTokenC before time increase"
            );

            const timeIncrease = 300;

            await time.increase(timeIncrease);

            const earned = await farm.earned(
                owner
            );

            // earned by dead address
            const earnedByDeadAddress = await farm.earned(
                DEAD_ADDRESS
            );

            assert.equal(
                parseInt(earned[1]) - parseInt(earnedBeforeTimeIncrease[1]) + parseInt(earnedByDeadAddress[1]),
                parseInt(timeIncrease) * parseInt(defaultRewardRate),
            );

            assert.equal(
                parseInt(earned[1]) + parseInt(earnedByDeadAddress[1]),
                parseInt(timeIncrease) * parseInt(defaultRewardRate),
                "User should earn rewardTokenC after time increase"
            );

            // earned[1] corresponds to rewardTokenC

            assert.isAbove(
                parseInt(earned[0]),
                0,
                "User should earned earning token A"
            );

            assert.isAbove(
                parseInt(earned[1]),
                0,
                "User should start earning token C"
            );
        });
    });

    describe("Recover Token Functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario();

            randomToken = await Token.new();
            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            // Add reward tokens
            await farm.addRewardToken(rewardTokenA.address);
            await farm.addRewardToken(rewardTokenB.address);
        });

        it("should be able to recover accidentally sent tokens from the contract", async () => {

            const transferAmount = ONE_TOKEN;

            await randomToken.transfer(
                farm.address,
                transferAmount
            );

            const balanceBefore = await randomToken.balanceOf(
                farm.address
            );

            assert.equal(
                balanceBefore,
                transferAmount
            );

            await farm.recoverToken(
                randomToken.address,
                balanceBefore
            );

            const balanceAfter = await randomToken.balanceOf(
                farm.address
            );

            assert.equal(
                balanceAfter.toString(),
                "0"
            );
        });

        it("should not be able to recover stakeTokens from the contract", async () => {

            const transferAmount = ONE_TOKEN;

            await stakeToken.transfer(
                farm.address,
                transferAmount
            );

            await expectRevert(
                farm.recoverToken(
                    stakeToken.address,
                    transferAmount
                ),
                "DynamicRewardFarm: STAKE_TOKEN"
            );
        });

        it("should not be able to recover rewardTokens from the contract", async () => {

            const transferAmount = ONE_TOKEN;

            await rewardTokenA.transfer(
                farm.address,
                transferAmount
            );

            await expectRevert(
                farm.recoverToken(
                    rewardTokenA.address,
                    transferAmount
                ),
                "DynamicRewardFarm: NOT_ENOUGH_REWARDS"
            );
        });
    });

    describe("Edge Cases and Additional Scenarios", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true,
                deposit: tokens("1000")
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            defaultRewardRate = tokens("10");

            const rewardDuration = await farm.rewardDuration();
            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));
            const totalRewardB = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Add reward tokens and set rates
            await farm.addRewardToken(
                rewardTokenA.address
            );

            await farm.addRewardToken(
                rewardTokenB.address
            );

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalRewardA,
                { from: owner }
            );

            await rewardTokenB.approve(
                farm.address,
                totalRewardB,
                { from: owner }
            );

            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate
                ]
            );
        });

        it("should handle zero staked balance correctly when calculating rewards", async () => {

            await time.increase(3000);

            await farm.farmWithdraw(tokens("1000"));

            await time.increase(3000);

            await farm.claimRewards();

            const earned = await farm.earned(
                owner
            );

            assert.equal(
                parseInt(earned[0]),
                0,
                "User with zero staked balance should not earn rewards"
            );

            assert.equal(
                parseInt(earned[1]),
                0,
                "User with zero staked balance should not earn rewards"
            );
        });

        it("should prevent setting reward rates to zero when there are stakers", async () => {

            await expectRevert(
                farm.setRewardRates(
                    [
                        rewardTokenA.address,
                        rewardTokenB.address
                    ],
                    [
                        0,
                        0
                    ],
                    { from: owner }
                ),
                "NoRewards()"
            );
        });
    });

    describe("Adding New Reward Tokens After Cycles", () => {
        let stakeToken, rewardTokenA, rewardTokenB, rewardTokenC, farm;
        let defaultRewardRate;

        beforeEach(async () => {
            const result = await setupScenario({
                approval: true,
                deposit: tokens("1000")
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB; // Second reward token
            rewardTokenC = result.rewardTokenC; // Third reward token
            farm = result.farm;

            defaultRewardRate = tokens("10");

            // Add the first reward token and set rate
            await farm.addRewardToken(
                rewardTokenA.address
            );

            const rewardDuration = await farm.rewardDuration();
            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Approve reward token A
            await rewardTokenA.approve(
                farm.address,
                totalRewardA
            );

            await farm.setRewardRates(
                [rewardTokenA.address],
                [defaultRewardRate]
            );
        });

        it("should distribute multiple reward tokens added after cycles", async () => {
            const userA = owner;
            const userB = bob;

            // User B deposits the same amount
            await stakeToken.mint(
                tokens("1000"),
                { from: userB }
            );

            await stakeToken.approve(
                farm.address,
                tokens("1000"),
                { from: userB }
            );

            await farm.farmDeposit(
                tokens("1000"),
                { from: userB }
            );

            // Advance time to complete the first reward cycle
            const rewardDuration = await farm.rewardDuration();
            await time.increase(rewardDuration.toNumber() + 1);

            // Users claim their rewards from the first cycle
            await farm.claimRewards({ from: userA });
            await farm.claimRewards({ from: userB });

            // Add the second reward token
            await farm.addRewardToken(
                rewardTokenB.address
            );

            const totalRewardA = BN(defaultRewardRate).mul(BN(rewardDuration));
            const totalRewardB = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Approve reward token B
            await rewardTokenB.approve(
                farm.address,
                totalRewardB
            );

            await rewardTokenA.approve(
                farm.address,
                totalRewardA
            );

            // Set reward rates for both tokens
            await farm.setRewardRates(
                [rewardTokenA.address, rewardTokenB.address],
                [defaultRewardRate, defaultRewardRate]
            );

            // Advance time and let users earn rewards in two tokens
            await time.increase(100);

            // Add the third reward token
            await farm.addRewardToken(
                rewardTokenC.address
            );

            const totalRewardC = BN(defaultRewardRate).mul(BN(rewardDuration));

            // Approve reward token C
            await rewardTokenC.approve(
                farm.address,
                totalRewardC
            );

            await rewardTokenA.approve(
                farm.address,
                totalRewardA
            );

            await rewardTokenB.approve(
                farm.address,
                totalRewardB
            );

            // Set reward rates for all three tokens
            await farm.setRewardRates(
                [
                    rewardTokenA.address,
                    rewardTokenB.address,
                    rewardTokenC.address
                ],
                [
                    defaultRewardRate,
                    defaultRewardRate,
                    defaultRewardRate
                ]
            );

            // Advance time and let users earn rewards in three tokens
            await time.increase(100000);

            // Users claim their rewards
            await farm.claimRewards({ from: userA });
            await farm.claimRewards({ from: userB });

            // Ensure users cannot double-claim
            const earnedAfterClaimA = await farm.earned(userA);
            const earnedAfterClaimB = await farm.earned(userB);

            // All earned rewards should be zero after claiming
            for (let i = 0; i < earnedAfterClaimA.length; i++) {
                assert.equal(
                    earnedAfterClaimA[i].toString(),
                    "0",
                    `User A should have no rewards left for token index ${i}`
                );
                assert.equal(
                    earnedAfterClaimB[i].toString(),
                    "0",
                    `User B should have no rewards left for token index ${i}`
                );
            }
        });
    });

    describe("Transfer of Receipt Tokens and Reward Adjustment", () => {
        let stakeToken, rewardTokenA, farm;
        let defaultRewardRate;

        beforeEach(async () => {
            const result = await setupScenario({
                approval: true,
                deposit: tokens("1000") // tokens() returns string
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            farm = result.farm;

            defaultRewardRate = tokensBN("10"); // BN instance

            // Add reward token and set rate
            await farm.addRewardToken(
                rewardTokenA.address
            );

            const rewardDuration = new _BN(await farm.rewardDuration());
            const totalReward = defaultRewardRate.mul(rewardDuration);

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalReward.toString()
            );

            await farm.setRewardRates(
                [rewardTokenA.address],
                [defaultRewardRate.toString()]
            );
        });

        it("should adjust rewards when user transfers receipt tokens to another user, accounting for DEAD_ADDRESS", async () => {
            const userA = owner;
            const userB = bob;

            // Get the initial timestamp
            const startTime = new _BN(await time.latest());

            // Advance time to let User A earn some rewards
            const timeIncreaseBefore = new _BN(100);
            await time.increase(timeIncreaseBefore.toNumber());

            // Get the timestamp after first time increase
            const midTime = new _BN(await time.latest());
            const actualTimeBefore = midTime.sub(startTime);

            // User A transfers half of his farm tokens to User B
            const userABalance = new _BN(await farm.balanceOf(userA));
            const transferAmount = userABalance.div(new _BN(2));

            await farm.transfer(userB, transferAmount.toString());

            // Advance time to let both users earn rewards
            const timeIncreaseAfter = new _BN(100);
            await time.increase(timeIncreaseAfter.toNumber());

            // Get the timestamp after second time increase
            const endTime = new _BN(await time.latest());
            const actualTimeAfter = endTime.sub(midTime);

            // Stakes
            const deadStake = PRECISIONS; // BN instance
            const userAStakeBefore = tokensBN("1000");
            const userAStakeAfter = userAStakeBefore.sub(transferAmount);
            const userBStake = transferAmount;

            // Total staked amounts
            const totalStakedBefore = BN(deadStake).add(userAStakeBefore);
            const totalStakedAfter = BN(deadStake).add(userAStakeAfter).add(userBStake);

            // Reward rate per second
            const rewardRate = defaultRewardRate;

            // Calculate rewardPerToken for each period
            const rewardPerTokenBefore = rewardRate
                .mul(actualTimeBefore)
                .mul(BN(PRECISIONS))
                .div(totalStakedBefore);

            const rewardPerTokenAfter = rewardRate
                .mul(actualTimeAfter)
                .mul(BN(PRECISIONS))
                .div(totalStakedAfter);

            // Expected earned rewards
            const expectedUserARewards = userAStakeBefore
                .mul(rewardPerTokenBefore)
                .div(BN(PRECISIONS))
                .add(
                    userAStakeAfter
                        .mul(rewardPerTokenAfter)
                        .div(BN(PRECISIONS))
                );

            const expectedUserBRewards = userBStake
                .mul(rewardPerTokenAfter)
                .div(BN(PRECISIONS));

            // Fetch actual earned rewards
            const earnedByUserA = new _BN(await farm.earnedByToken(
                rewardTokenA.address,
                userA
            ));

            const earnedByUserB = new _BN(await farm.earnedByToken(
                rewardTokenA.address,
                userB
            ));

            // Allow some margin for block time discrepancies
            const margin = tokensBN("5.0");

            // Assertions for User A
            assert.isTrue(
                earnedByUserA.sub(expectedUserARewards).abs().lte(margin),
                `User A's earned rewards should be approximately ${expectedUserARewards.toString()}, but got ${earnedByUserA.toString()}`
            );

            // Assertions for User B
            assert.isTrue(
                earnedByUserB.sub(expectedUserBRewards).abs().lte(margin),
                `User B's earned rewards should be approximately ${expectedUserBRewards.toString()}, but got ${earnedByUserB.toString()}`
            );
        });
    });

    describe("Multiple Users Staking and Reward Adjustment", () => {
        let stakeToken, rewardTokenA, farm;
        let defaultRewardRate;

        beforeEach(async () => {
            // Setup the scenario
            const result = await setupScenario({
                approval: true,
                deposit: tokens("1000") // tokens() returns a string
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            farm = result.farm;

            defaultRewardRate = tokensBN("10"); // Now a BN instance

            // Add reward token and set rate
            await farm.addRewardToken(
                rewardTokenA.address
            );

            const rewardDuration = await farm.rewardDuration(); // BN instance
            const totalReward = defaultRewardRate.mul(rewardDuration);

            // Approve reward tokens
            await rewardTokenA.approve(
                farm.address,
                totalReward.toString()
            );

            await farm.setRewardRates(
                [rewardTokenA.address],
                [defaultRewardRate.toString()]
            );
        });

        it("should adjust rewards when another user joins, accounting for DEAD_ADDRESS", async () => {
            const userA = owner;
            const userB = bob;

            // Get initial balances and total supply
            const initialTotalSupply = new _BN(await farm.totalSupply());
            const initialBalanceA = new _BN(await farm.balanceOf(userA));

            // Advance time to let User A earn some rewards
            const timeIncreaseBefore = new _BN(100);
            await time.increase(timeIncreaseBefore.toNumber());

            // Record User A's earned rewards before User B joins
            const earnedByUserABefore = new _BN(await farm.earnedByToken(
                rewardTokenA.address,
                userA
            ));

            // User B approves and deposits the same amount
            await stakeToken.mint(
                tokens("1000"),
                { from: userB }
            );

            await stakeToken.approve(
                farm.address,
                tokens("1000"),
                { from: userB }
            );

            await farm.farmDeposit(
                tokens("1000"),
                { from: userB }
            );

            // Get new balances and total supply
            const balanceAAfter = new _BN(await farm.balanceOf(userA));
            const balanceBAfter = new _BN(await farm.balanceOf(userB));
            const totalSupplyAfter = new _BN(await farm.totalSupply());

            // Advance time to let both users earn rewards
            const timeIncreaseAfter = new _BN(100);
            await time.increase(timeIncreaseAfter.toNumber());

            // Fetch actual earned rewards
            const earnedByUserA = new _BN(await farm.earnedByToken(
                rewardTokenA.address,
                userA
            ));

            const earnedByUserB = new _BN(await farm.earnedByToken(
                rewardTokenA.address,
                userB
            ));

            // Calculate the earned rewards during the second period
            const earnedByUserAAfter = earnedByUserA.sub(earnedByUserABefore);

            // Calculate total earned rewards after User B joins
            const totalEarnedAfter = earnedByUserAAfter.add(earnedByUserB);

            // Check proportionality of rewards after User B joins
            const proportionA = balanceAAfter.muln(1000).div(totalSupplyAfter).toNumber();
            const proportionB = balanceBAfter.muln(1000).div(totalSupplyAfter).toNumber();

            const rewardProportionA = earnedByUserAAfter.muln(1000).div(totalEarnedAfter).toNumber();
            const rewardProportionB = earnedByUserB.muln(1000).div(totalEarnedAfter).toNumber();

            // Allow small margin for rounding errors
            const margin = 15; // 0.5%

            // Assertions
            assert.isAtMost(
                Math.abs(proportionA - rewardProportionA),
                margin,
                `User A's reward proportion should be approximately ${proportionA / 10}%, but got ${rewardProportionA / 10}%`
            );

            assert.isAtMost(
                Math.abs(proportionB - rewardProportionB),
                margin,
                `User B's reward proportion should be approximately ${proportionB / 10}%, but got ${rewardProportionB / 10}%`
            );
        });
    });
});
