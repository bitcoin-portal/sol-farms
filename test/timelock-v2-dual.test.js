const Token = artifacts.require("TestToken");
const Farm = artifacts.require("TimeLockFarmV2Dual");
const { expectRevert, time } = require('@openzeppelin/test-helpers');

require("./utils");

const _BN = web3.utils.BN;
const BN = (value) => {
    return new _BN(
        value
    );
}

const tokens = (value) => {
    return web3.utils.toWei(
        value
    );
}

const ONE_TOKEN = tokens("1");
const TWO_TOKENS = tokens("2");
const FIVE_TOKENS = tokens("5");

const MAX_VALUE = BN(2)
    .pow(BN(256))
    .sub(BN(1));

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest",
    });
    return events.pop().returnValues;
};

contract("TimeLockFarmV2Dual", ([owner, alice, bob, chad, random]) => {

    const setupScenario = async (inputParams = {}) => {

        stakeToken = await Token.new();
        rewardTokenA = await Token.new();
        rewardTokenB = await Token.new();

        defaultUnlockTime = 150;
        expectedUnlockTime = 150;
        defaultApprovalAmount = 100;
        defaultDurationInSeconds = 300;

        farm = await Farm.new(
            stakeToken.address,
            rewardTokenA.address,
            rewardTokenB.address,
            defaultUnlockTime
        );

        await farm.changeManager(
            owner
        );

        if (inputParams.approval) {

            const approvalAmount = tokens(
                defaultApprovalAmount.toString()
            );

            await stakeToken.approve(
                farm.address,
                approvalAmount
            );

            await rewardTokenA.approve(
                farm.address,
                approvalAmount
            );

            await rewardTokenB.approve(
                farm.address,
                approvalAmount
            );
        }


        if (inputParams.deposit) {
            await farm.makeDepositForUser(
                owner,
                inputParams.deposit,
                defaultDurationInSeconds
            );
        }

        if (inputParams.rate) {
            await farm.setRewardRates(
                inputParams.rate,
                inputParams.rate
            );
        }

        return {
            stakeToken,
            rewardTokenA,
            rewardTokenB,
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
            const expectedDefaultValue = 0;

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

        it("should have correct reward token address", async () => {

            const rewardTokenValue = await farm.rewardTokenA();

            assert.equal(
                rewardTokenValue,
                rewardTokenA.address
            );
        });

        it("should have correct reward token address", async () => {

            const rewardTokenValue = await farm.rewardTokenB();

            assert.equal(
                rewardTokenValue,
                rewardTokenB.address
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

            console.log(owner, 'owner');

            assert.equal(
                managerAddress,
                owner
            );
        });

        it("should have correct perTokenStored value", async () => {

            const perTokenStored = await farm.perTokenStoredA();
            const expectedDefaultValue = 0;

            assert.equal(
                perTokenStored,
                expectedDefaultValue
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
                defaultDurationValue.toString(),
                expectedUnlockTime.toString()
            );
        });

        it("should not be able to deploy with wrong default duration value", async () => {

            const invalidDuration = 0;
            const correctDuration = 1;

            await expectRevert(
                Farm.new(
                    stakeToken.address,
                    rewardTokenA.address,
                    rewardTokenB.address,
                    invalidDuration
                ),
                "TimeLockFarmV2Dual: INVALID_DURATION"
            );

            await Farm.new(
                stakeToken.address,
                rewardTokenA.address,
                rewardTokenB.address,
                correctDuration
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
            const expectedDefaultDuration = expectedUnlockTime;
            const newDurationValueIncrease = 600;
            const newDurationValueDecrease = 100;

            assert.equal(
                defaultDuration.toString(),
                expectedDefaultDuration.toString()
            );

            assert.isAbove(
                parseInt(newDurationValueIncrease),
                parseInt(defaultDuration)
            );

            assert.isBelow(
                parseInt(newDurationValueDecrease),
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
                durationValueIncreased
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
                "TimeLockFarmV2Dual: INVALID_MANAGER"
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
            const expectedDefaultDuration = expectedUnlockTime;

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
                "TimeLockFarmV2Dual: INVALID_DURATION"
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
            const expectedDefaultDuration = expectedUnlockTime;
            const newDurationWrongValue = 100;

            assert.equal(
                defaultDuration,
                expectedDefaultDuration
            );

            await farm.makeDepositForUser(
                owner,
                10,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                10,
                10
            );

            await expectRevert(
                farm.setRewardDuration(
                    newDurationWrongValue
                ),
                "TimeLockFarmV2Dual: ONGOING_DISTRIBUTION"
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
        });

        it("should not be able to set rate to 0", async () => {

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await expectRevert(
                farm.setRewardRates(
                    0,
                    0,
                ),
                "TimeLockFarmV2Dual: INVALID_RATE"
            );

            await expectRevert(
                farm.setRewardRates(
                    1,
                    0,
                ),
                "TimeLockFarmV2Dual: INVALID_RATE"
            );

            await expectRevert(
                farm.setRewardRates(
                    0,
                    1,
                ),
                "TimeLockFarmV2Dual: INVALID_RATE"
            );

            await farm.setRewardRates(
                1,
                1
            );
        });

        it("should correctly set the periodFinished date value", async () => {

            const initialPeriod = await farm.periodFinished();
            const expectedDuration = await farm.rewardDuration();
            const initialRate = 10;
            const expectedInitialValue = 0;

            assert.equal(
                initialPeriod,
                expectedInitialValue
            );

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                initialRate,
                initialRate,
            );

            const initialTimestamp = await rewardTokenA.timestamp();
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

        it("should increase perTokenStored value", async () => {

            const perTokenStoredDefault = await farm.perTokenStoredA();
            const expectedDefaultValue = 0;
            const initialRate = 10;

            assert.equal(
                perTokenStoredDefault,
                expectedDefaultValue
            );

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                initialRate,
                initialRate
            );

            await time.increase(
                1
            );

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            const perTokenStoredNew = await farm.perTokenStoredA();

            assert.isAbove(
                parseInt(perTokenStoredNew),
                parseInt(perTokenStoredDefault)
            );
        });

        it("should emit correct RewardAdded event", async () => {

            const initialRate = 10;
            const rewardDuration = await farm.rewardDuration();
            const expectedAmount = rewardDuration * initialRate;

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                initialRate,
                initialRate
            );

            const rewardEvent = await getLastEvent(
                "RewardAdded",
                farm
            );

            assert.equal(
                expectedAmount,
                rewardEvent.tokenAmount
            );
        });

        it("manager should be able to set rewards rate only if stakers exist", async () => {

            const newRewardRate = 10;
            const expectedNewRate = newRewardRate;

            await expectRevert(
                farm.setRewardRates(
                    newRewardRate,
                    newRewardRate
                ),
                "TimeLockFarmV2Dual: NO_STAKERS"
            );

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                newRewardRate,
                newRewardRate
            );

            const rateAfterChangedA = await farm.rewardRateA();
            const rateAfterChangedB = await farm.rewardRateB();

            assert.equal(
                rateAfterChangedA,
                expectedNewRate
            );

            assert.equal(
                rateAfterChangedB,
                expectedNewRate
            );
        });

        it("manager should fund the farm during reward rate announcement", async () => {

            const newRewardRate = 10;
            const expectedDuration = await farm.rewardDuration();
            const currentManager = await farm.managerAddress();

            const expectedTransferAmount = newRewardRate
                * expectedDuration;

            const managerBalance = await rewardTokenA.balanceOf(
                currentManager
            );

            assert.isAbove(
                parseInt(managerBalance),
                expectedTransferAmount
            );

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                newRewardRate,
                newRewardRate
            );

            const transferData = await getLastEvent(
                "Transfer",
                rewardTokenA
            );

            assert.equal(
                transferData.from,
                currentManager
            );

            assert.equal(
                transferData.to,
                farm.address
            );

            assert.equal(
                transferData.value,
                expectedTransferAmount
            );

            const afterTransferManager = await rewardTokenA.balanceOf(
                currentManager
            );

            const afterTransferFarm = await rewardTokenA.balanceOf(
                farm.address
            );

            assert.equal(
                managerBalance,
                parseInt(afterTransferManager) + parseInt(expectedTransferAmount)
            );

            assert.equal(
                expectedTransferAmount,
                afterTransferFarm
            );
        });

        it("manager should be able to increase rate any time", async () => {

            const initialRate = 10;
            const increasedRewardRate = 11;

            assert.isAbove(
                increasedRewardRate,
                initialRate
            );

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                initialRate,
                initialRate
            );

            const rateBeforeChanged = await farm.rewardRateA();

            assert.equal(
                rateBeforeChanged,
                initialRate
            );

            await farm.setRewardRates(
                increasedRewardRate,
                increasedRewardRate
            );

            const rateAfterChanged = await farm.rewardRateA();

            assert.equal(
                rateAfterChanged,
                increasedRewardRate
            );
        });

        it("manager should be able to decrease rate only after distribution finished", async () => {

            const initialRate = 10;
            const decreasedRewardRate = 9;

            assert.isBelow(
                decreasedRewardRate,
                initialRate
            );

            await farm.makeDepositForUser(
                owner,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                initialRate,
                initialRate
            );

            const rateAfterChanged = await farm.rewardRateA();

            assert.equal(
                rateAfterChanged,
                initialRate
            );

            await expectRevert(
                farm.setRewardRates(
                    decreasedRewardRate,
                    decreasedRewardRate
                ),
                "TimeLockFarmV2Dual: RATE_A_CANT_DECREASE"
            );

            const currentDuration = await farm.rewardDuration();

            await time.increase(
                currentDuration
            );

            await farm.setRewardRates(
                decreasedRewardRate,
                decreasedRewardRate
            );

            const newRate = await farm.rewardRateA();

            assert.equal(
                parseInt(newRate),
                decreasedRewardRate
            );
        });
    });

    describe("Deposit initial functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;
        });

        it("should transfer correct amount from farmer to farm", async () => {

            const depositValue = ONE_TOKEN;
            const depositAddress = bob;

            await stakeToken.mint(
                depositValue,
                {
                    from: depositAddress
                }
            );

            //@TODO: test without approve
            await stakeToken.approve(
                farm.address,
                depositValue,
                {
                    from: depositAddress
                }
            );

            const balanceBefore = await stakeToken.balanceOf(
                depositAddress
            );

            await farm.makeDepositForUser(
                depositAddress,
                ONE_TOKEN,
                defaultUnlockTime
            );

            const balanceAfter = await stakeToken.balanceOf(
                depositAddress
            );

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(depositValue)
            );
        });

        it("should increase the balance of the wallet thats deposits the tokens", async () => {

            const depositAmount = ONE_TOKEN;

            const supplyBefore = await farm.balanceOf(
                owner
            );

            await farm.makeDepositForUser(
                owner,
                depositAmount,
                defaultUnlockTime
            );

            const supplyAfter = await farm.balanceOf(
                owner
            );

            assert.equal(
                parseInt(supplyAfter),
                parseInt(supplyBefore) + parseInt(depositAmount)
            );
        });

        it("should add the correct amount to the total supply", async () => {

            const supplyBefore = await farm.balanceOf(owner);
            const depositAmount = ONE_TOKEN;

            await farm.makeDepositForUser(
                owner,
                depositAmount,
                defaultUnlockTime
            );

            const totalSupply = await farm.totalSupply();

            assert.equal(
                totalSupply.toString(),
                (BN(supplyBefore).add(BN(depositAmount))).toString()
            );
        });

        it("should not be able to deposit if not appored enough", async () => {

            const allowance = await stakeToken.allowance(
                owner,
                farm.address
            );

            const depositAmount = tokens("2000");

            assert.isAbove(
                parseInt(depositAmount),
                parseInt(allowance)
            );

            await expectRevert.unspecified(
                farm.makeDepositForUser(
                    owner,
                    depositAmount,
                    defaultUnlockTime
                ),
                "SafeERC20: CALL_FAILED"
            );
        });
    });

    describe("Receipt token approve functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true,
                deposit: ONE_TOKEN
            });

            farm = result.farm;
        });

        it("should be able to increase allowance", async () => {

            const initialAllowance = await farm.allowance(
                owner,
                bob
            );

            const increaseValue = ONE_TOKEN;

            await farm.increaseAllowance(
                bob,
                increaseValue
            );

            const allowanceIncreased = await farm.allowance(
                owner,
                bob
            );

            assert.isAbove(
                parseInt(allowanceIncreased),
                parseInt(initialAllowance)
            );

            assert.equal(
                parseInt(allowanceIncreased),
                parseInt(initialAllowance) + parseInt(increaseValue)
            );
        });

        it("should be able to decrease allowance", async () => {

            await farm.approve(
                bob,
                ONE_TOKEN
            );

            const initialAllowance = await farm.allowance(
                owner,
                bob
            );

            const decreaseValue = ONE_TOKEN;

            await farm.decreaseAllowance(
                bob,
                decreaseValue
            );

            const allowanceDecreased = await farm.allowance(
                owner,
                bob
            );

            assert.isBelow(
                parseInt(allowanceDecreased),
                parseInt(initialAllowance)
            );

            assert.equal(
                parseInt(allowanceDecreased),
                parseInt(initialAllowance) - parseInt(decreaseValue)
            );
        });

        it("should not change allowance if its at maximum", async () => {

            const approvalValue = MAX_VALUE;
            const transferValue = ONE_TOKEN;

            await stakeToken.mint(
                transferValue,
                {
                    from: owner
                }
            );

            await stakeToken.approve(
                farm.address,
                approvalValue
            );

            await farm.makeDepositForUser(
                bob,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.approve(
                bob,
                approvalValue
            );

            const allowanceValueBefore = await farm.allowance(
                owner,
                bob
            );

            assert.equal(
                MAX_VALUE.toString(),
                allowanceValueBefore.toString()
            );

            await time.increase(
                defaultUnlockTime * 2
            );

            await farm.transferFrom(
                owner,
                alice,
                transferValue,
                {
                    from: bob
                }
            );

            const allowanceValueAfter = await farm.allowance(
                owner,
                bob
            );

            assert.equal(
                allowanceValueBefore.toString(),
                allowanceValueAfter.toString()
            );

            assert.equal(
                MAX_VALUE.toString(),
                allowanceValueAfter.toString()
            );
        });

        it("should revert if the sender has spent more than their approved amount", async () => {

            const approvedValue = ONE_TOKEN;
            const transferValue = TWO_TOKENS;
            const approvedWallet = alice;

            await farm.approve(
                approvedWallet,
                approvedValue
            );

            await expectRevert.unspecified(
                farm.transferFrom(
                    owner,
                    bob,
                    transferValue,
                    {
                        from: approvedWallet
                    }
                )
            );
        });
    });

    describe("Receipt token burn/mint functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            farm = result.farm;
            defaultTokenAmount = TWO_TOKENS;
            ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
        });

        it("should emit correct event when minting receipt tokens (during deposit)", async () => {

            const depositor = owner;

            await farm.makeDepositForUser(
                depositor,
                defaultTokenAmount,
                defaultUnlockTime
            );

            const { from, to, value } = await getLastEvent(
                "Transfer",
                farm
            );

            assert.equal(
                value,
                defaultTokenAmount
            );

            assert.equal(
                from,
                ZERO_ADDRESS
            );

            assert.equal(
                to,
                depositor
            );
        });

        it("should emit correct event when burning receipt tokens (during withdraw)", async () => {

            const depositor = owner;

            await farm.makeDepositForUser(
                depositor,
                defaultTokenAmount,
                defaultUnlockTime
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.farmWithdraw(
                defaultTokenAmount,
                {
                    from: depositor
                }
            );

            const { from, to, value } = await getLastEvent(
                "Transfer",
                farm
            );

            assert.equal(
                value,
                defaultTokenAmount
            );

            assert.equal(
                from,
                depositor
            );

            assert.equal(
                to,
                ZERO_ADDRESS
            );
        });
    });

    describe("Receipt token transfer functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenBs;
            farm = result.farm;

            defaultTokenAmount = TWO_TOKENS;

            await farm.makeDepositForUser(
                owner,
                defaultTokenAmount,
                defaultUnlockTime
            );
        });

        it("should transfer correct amount from walletA to walletB", async () => {

            const transferValue = defaultTokenAmount;
            const balanceBefore = await farm.balanceOf(bob);

            await time.increase(
                defaultUnlockTime
            );

            await farm.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await farm.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await farm.balanceOf(alice);

            await expectRevert.unspecified(
                farm.transfer(
                    bob,
                    parseInt(balanceBefore) + 1,
                    {
                        from: alice
                    }
                )
            );
        });

        it("if tokens unlocked should reduce wallets balance after transfer", async () => {

            const transferValue = defaultTokenAmount;
            const balanceBefore = await farm.balanceOf(owner);

            await expectRevert(
                farm.transfer(
                    bob,
                    transferValue,
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await farm.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("if tokens unlocked should emit correct Transfer event", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecepient = bob;

            await expectRevert(
                farm.transfer(
                    expectedRecepient,
                    transferValue,
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.transfer(
                expectedRecepient,
                transferValue,
                {
                    from: owner
                }
            );

            const { from, to, value } = await getLastEvent(
                "Transfer",
                farm
            );

            assert.equal(
                from,
                owner
            );

            assert.equal(
                to,
                expectedRecepient
            );

            assert.equal(
                value,
                transferValue
            );
        });

        it("if tokens unlocked should update the balance of the recipient when using transferFrom", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecipient = bob;
            const balanceBefore = await farm.balanceOf(bob);

            await farm.approve(
                owner,
                transferValue
            );

            await expectRevert(
                farm.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue,
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await farm.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("if tokens unlocked should deduct from the balance of the sender when using transferFrom", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecipient = bob;
            const balanceBefore = await farm.balanceOf(owner);

            await farm.approve(
                owner,
                transferValue
            );

            await expectRevert(
                farm.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue,
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await farm.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should revert if there is no approval when using transferFrom", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecipient = bob;

            await expectRevert.unspecified(
                farm.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue
                )
            );
        });

        it("should revert if the sender has spent more than their approved amount when using transferFrom", async () => {

            const approvedValue = ONE_TOKEN;
            const transferValue = TWO_TOKENS;
            const expectedRecipient = bob;

            await farm.approve(
                alice,
                approvedValue
            );

            await expectRevert.unspecified(
                farm.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue,
                    {
                        from: alice
                    }
                )
            );
        });
    });

    describe("Witharaw initial functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;

            defaultTokenAmount = TWO_TOKENS;

            await farm.makeDepositForUser(
                owner,
                defaultTokenAmount,
                defaultUnlockTime
            );
        });

        it("if tokens unlocked should reduce the balance of the wallet thats withrawing the stakeTokens", async () => {

            const withdrawAmount = ONE_TOKEN;
            const withdrawAccount = owner;

            const supplyBefore = await farm.balanceOf(
                withdrawAccount
            );

            await expectRevert(
                farm.farmWithdraw(
                    withdrawAmount,
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.farmWithdraw(
                withdrawAmount,
                {
                    from: withdrawAccount
                }

            );

            const supplyAfter = await farm.balanceOf(
                withdrawAccount
            );

            assert.equal(
                supplyAfter,
                supplyBefore - withdrawAmount
            );
        });

        it("should deduct the correct amount from the total supply", async () => {

            const withdrawAmount = ONE_TOKEN;
            const withdrawAccount = owner;

            const supplyBefore = await farm.balanceOf(
                withdrawAccount
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.farmWithdraw(
                withdrawAmount,
                {
                    from: owner
                }

            );

            const totalSupply = await farm.totalSupply();

            assert.equal(
                totalSupply,
                supplyBefore - withdrawAmount
            );
        });

        it("should not be able to withdraw as last farmer until rewards are still available", async () => {

            await farm.makeDepositForUser(
                owner,
                defaultTokenAmount,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                10,
                10
            );

            const withdrawAccount = owner;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            await expectRevert(
                farm.farmWithdraw(
                    possibleWithdraw,
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await stakeToken.mint(
                defaultTokenAmount
            );

            await stakeToken.approve(
                farm.address,
                defaultTokenAmount
            );

            await farm.makeDepositForUser(
                bob,
                defaultTokenAmount,
                defaultUnlockTime
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.farmWithdraw(
                possibleWithdraw,
                {
                    from: owner
                }
            );
        });
    });

    describe("Witharaw with timelock functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            defaultDepositAmount = TWO_TOKENS;

            await farm.makeDepositForUser(
                owner,
                defaultDepositAmount,
                defaultUnlockTime
            );
        });

        it("should have correct stake count", async () => {

            const expectedAccount = owner;
            const expectedCount = 1;

            const userStakeCount = await farm.stakeCount(
                expectedAccount
            );

            assert.equal(
                userStakeCount,
                expectedCount
            );
        });

        it("should create stake object for account when stake created", async () => {

            const expectedAccount = owner;
            const expectedDeposit = defaultDepositAmount;

            const stampAfterDeposit = await rewardTokenA.timestamp();

            const stakeCount = await farm.stakeCount(
                expectedAccount
            );

            const latestStakeIndex = stakeCount - 1;

            const userStakeOne = await farm.stakes(
                expectedAccount,
                latestStakeIndex
            );

            assert.equal(
                userStakeOne.amount.toString(),
                expectedDeposit.toString()
            );

            /* @TODO: check
            assert.equal(
                parseInt(userStakeOne.unlockTime),
                parseInt(stampAfterDeposit) + parseInt(timeLock)
            );
            */
        });

        it("checks that if tokens are locked then user cannot withdraw them", async () => {

            const withdrawAmount = defaultDepositAmount;
            const withdrawAccount = owner;

            const unlockedBefore = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockedBefore,
                "0"
            );

            await expectRevert(
                farm.farmWithdraw(
                    withdrawAmount,
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                defaultUnlockTime
            );

            const unlockedAfter = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockedAfter,
                defaultDepositAmount
            );

            await farm.farmWithdraw(
                withdrawAmount,
                {
                    from: withdrawAccount
                }

            );

            const transactionData = await getLastEvent(
                "Withdrawn",
                farm
            );

            assert.equal(
                transactionData.user,
                withdrawAccount
            );

            assert.equal(
                transactionData.tokenAmount,
                defaultDepositAmount
            );
        });

        it("should unlock stakes only once unlock time passed for each stake", async () => {

            const withdrawAccount = owner;
            const withdrawAmountOne = defaultDepositAmount;
            const withdrawAmountTwo = FIVE_TOKENS;
            const halfTime = defaultUnlockTime / 2

            assert.isAbove(
                parseInt(withdrawAmountTwo),
                parseInt(withdrawAmountOne)
            );

            await time.increase(
                halfTime
            );

            await farm.makeDepositForUser(
                owner,
                withdrawAmountTwo,
                defaultUnlockTime
            );

            const userStakeCount = await farm.stakeCount(
                withdrawAccount
            );

            assert.equal(
                userStakeCount.toString(),
                "2"
            );

            await time.increase(
                halfTime
            );

            const unlockableFirstStake = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableFirstStake.toString(),
                withdrawAmountOne.toString()
            );

            await expectRevert(
                farm.farmWithdraw(
                    withdrawAmountTwo,
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await farm.farmWithdraw(
                withdrawAmountOne,
                {
                    from: withdrawAccount
                }
            );

            const userStakeCountAgain = await farm.stakeCount(
                withdrawAccount
            );

            assert.equal(
                userStakeCountAgain.toString(),
                "1"
            );

            const unlockableSecondStake = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableSecondStake.toString(),
                "0"
            );

            await expectRevert(
                farm.farmWithdraw(
                    withdrawAmountOne,
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await expectRevert(
                farm.farmWithdraw(
                    withdrawAmountTwo,
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                halfTime
            );

            const unlockableSecondStakeAgain = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableSecondStakeAgain.toString(),
                withdrawAmountTwo.toString()
            );

            await farm.farmWithdraw(
                withdrawAmountTwo,
                {
                    from: withdrawAccount
                }
            );

            const unlockableFinal = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableFinal.toString(),
                "0"
            );

            const finalStakeCount = await farm.stakeCount(
                withdrawAccount
            );

            assert.equal(
                finalStakeCount.toString(),
                "0"
            );
        });

        it("should reduce stake amount when withdrawing if stoke is unlocked", async () => {

            const withdrawAccount = owner;
            const withdrawAmount = tokens("2");
            const halfAmount = tokens("1");

            const stakeCount = await farm.stakeCount(
                withdrawAccount
            );

            const latestStakeIndex = stakeCount - 1;
            const userStake = await farm.stakes(
                withdrawAccount,
                latestStakeIndex
            );

            assert.equal(
                userStake.amount.toString(),
                withdrawAmount.toString()
            );

            const unlockableInitial = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableInitial.toString(),
                "0"
            );

            await time.increase(
                defaultUnlockTime
            );

            const unlockableFirstStake = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableFirstStake,
                withdrawAmount
            );

            await farm.farmWithdraw(
                halfAmount,
                {
                    from: withdrawAccount
                }
            );

            const userStakeCountAgain = await farm.stakeCount(
                withdrawAccount
            );

            assert.equal(
                userStakeCountAgain.toString(),
                "1"
            );

            const userStakeAgain = await farm.stakes(
                withdrawAccount,
                latestStakeIndex
            );

            assert.isBelow(
                parseInt(userStakeAgain.amount),
                parseInt(withdrawAmount)
            );

            assert.equal(
                userStakeAgain.amount.toString(),
                halfAmount.toString()
            );

            await expectRevert(
                farm.farmWithdraw(
                    withdrawAmount,
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await farm.farmWithdraw(
                halfAmount,
                {
                    from: withdrawAccount
                }
            );

            const unlockableFinal = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableFinal.toString(),
                "0"
            );

            const finalStakeCount = await farm.stakeCount(
                withdrawAccount
            );

            assert.equal(
                finalStakeCount.toString(),
                "0"
            );
        });

        it("should unlock stake only once unlock time passed", async () => {

            const withdrawAccount = owner;
            const withdrawAmount = defaultDepositAmount;
            const halfTime = defaultUnlockTime / 2;

            const unlockableStepOne = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableStepOne.toString(),
                "0"
            );

            await time.increase(
                halfTime
            );

            const unlockableStepTwo = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableStepTwo.toString(),
                "0"
            );

            await expectRevert(
                farm.farmWithdraw(
                    withdrawAmount,
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: UNLOCK_INSUFFICIENT"
            );

            await time.increase(
                halfTime
            );

            const unlockableStepThree = await farm.unlockable(
                withdrawAccount
            );

            assert.equal(
                unlockableStepThree,
                withdrawAmount
            );

            await farm.farmWithdraw(
                withdrawAmount,
                {
                    from: owner
                }
            );
        });

        it("should not be able to withdraw as last farmer until rewards are still available", async () => {

            await farm.makeDepositForUser(
                owner,
                defaultTokenAmount,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                10,
                10
            );

            const withdrawAccount = owner;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            await expectRevert(
                farm.farmWithdraw(
                    possibleWithdraw,
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: STILL_EARNING"
            );

            await stakeToken.mint(
                defaultTokenAmount,
                {
                    from: bob
                }
            );

            await stakeToken.approve(
                farm.address,
                defaultTokenAmount,
                {
                    from: bob
                }
            );

            await farm.makeDepositForUser(
                defaultTokenAmount,
                {
                    from: bob
                }
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.farmWithdraw(
                possibleWithdraw,
                {
                    from: owner
                }
            );
        });
    });

    describe("Owner functionality", () => {

        beforeEach(async () => {
            const result = await setupScenario();
            farm = result.farm;
        });

        it("should have correct owner address", async () => {

            const expectedAddress = owner;
            const ownerAddress = await farm.ownerAddress();

            assert.equal(
                expectedAddress,
                ownerAddress
            );
        });

        it("should have correct owner address based on deployment parameters", async () => {

            const expectedAddress = owner;

            const newFarm = await Farm.new(
                stakeToken.address,
                rewardTokenA.address,
                rewardTokenB.address,
                defaultUnlockTime,
                {
                    from: owner
                }
            );

            const ownerAddress = await newFarm.ownerAddress();

            assert.equal(
                expectedAddress,
                ownerAddress
            );
        });
    });

    describe("Manager functionality", () => {

        beforeEach(async () => {
            const result = await setupScenario();
            farm = result.farm;
        });

        it("should have correct manager address", async () => {

            const expectedAddress = owner;
            const managerAddress = await farm.managerAddress();

            assert.equal(
                expectedAddress,
                managerAddress
            );
        });

        it("should have correct manager address based on deployment wallet", async () => {

            const expectedManager = alice;

            const newFarm = await Farm.new(
                stakeToken.address,
                rewardTokenA.address,
                rewardTokenB.address,
                defaultUnlockTime,
                {
                    from: random
                }
            );

            await newFarm.changeManager(
                alice,
                {
                    from: random
                }
            );

            const managerAddress = await newFarm.managerAddress();

            assert.equal(
                expectedManager,
                managerAddress
            );
        });

        it("should be able to change manager only by owner address", async () => {

            const expectedCurrentOwner = owner;
            const expectedCurrentManager = owner;
            const newManager = bob;
            const wrongOwner = alice;

            const currentOwner = await farm.ownerAddress();
            const currentManager = await farm.managerAddress();

            assert.equal(
                currentOwner,
                expectedCurrentOwner
            );

            assert.equal(
                currentManager,
                expectedCurrentManager
            );

            await expectRevert(
                farm.changeManager(
                    newManager,
                    {
                        from: wrongOwner
                    }
                ),
                "TimeLockFarmV2Dual: INVALID_OWNER"
            );

            await farm.changeManager(
                newManager,
                {
                    from: currentOwner
                }
            );

            const newManagerAfterChange = await farm.managerAddress();

            assert.notEqual(
                currentManager,
                newManagerAfterChange
            );

            assert.equal(
                newManager,
                newManagerAfterChange
            );
        });

        it("should revert if newManager is ZERO_ADDRESS", async () => {

            const wrongAddress = "0x0000000000000000000000000000000000000000";
            const rightAddress = "0x0000000000000000000000000000000000000001";

            await expectRevert(
                farm.changeManager(
                    wrongAddress,
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: WRONG_ADDRESS"
            );

            await farm.changeManager(
                rightAddress,
                {
                    from: owner
                }
            );

            const managerAddress = await farm.managerAddress();

            assert.equal(
                rightAddress,
                managerAddress
            );
        });

        it("should emit correct ManagerChanged event", async () => {

            const newManager = bob;

            await farm.changeManager(
                newManager
            );

            const newManagerAfterChange = await farm.managerAddress();

            assert.equal(
                newManager,
                newManagerAfterChange
            );

            const transactionData = await getLastEvent(
                "ManagerChanged",
                farm
            );

            assert.equal(
                transactionData.newManager,
                newManagerAfterChange
            );
        });
    });

    describe("Earn functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;

            defaultTokenAmount = TWO_TOKENS;
            defaultRewardRate = 10;

            await farm.makeDepositForUser(
                owner,
                defaultTokenAmount,
                defaultUnlockTime
            );

            await stakeToken.mint(
                defaultTokenAmount,
                {
                    from: bob
                }
            );

            await stakeToken.approve(
                farm.address,
                defaultTokenAmount,
                {
                    from: bob
                }
            );
        });

        it("should earn rewards proportionally to stake time", async () => {

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const stepTimeFrame = 1;
            const expectedDefaultEarn = 0;
            const rewardRate = await farm.rewardRateA();
            const earnPerStep = stepTimeFrame * rewardRate;

            const earnedInital = await farm.earnedA(
                owner
            );

            assert.equal(
                parseInt(earnedInital),
                parseInt(expectedDefaultEarn)
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedStep1 = await farm.earnedA(
                owner
            );

            assert.isAtLeast(
                parseInt(earnedStep1) + 1,
                earnPerStep * 1
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedStep2 = await farm.earnedA(
                owner
            );

            assert.isAtLeast(
                parseInt(earnedStep2) + 1,
                earnPerStep * 2
            );
        });

        it("should earn rewards proportionally to staked amount single", async () => {

            await farm.makeDepositForUser(
                bob,
                defaultTokenAmount,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const stepTimeFrame = 1;
            const expectedDefaultEarn = 0;

            const depositedByOwner = await farm.balanceOf(
                owner
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            assert.equal(
                depositedByOwner.toString(),
                depositedByBob.toString()
            );

            const earnedInitalOwner = await farm.earnedA(
                owner
            );

            const earnedInitalBob = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedInitalOwner.toString(),
                earnedInitalBob.toString()
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedOwnerStep1 = await farm.earnedA(
                owner
            );

            const earnedBobStep1 = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedOwnerStep1.toString(),
                earnedBobStep1.toString()
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedOwnerStep2 = await farm.earnedA(
                owner
            );

            const earnedBobStep2 = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedOwnerStep2.toString(),
                earnedBobStep2.toString()
            );

            assert.isAbove(
                parseInt(earnedOwnerStep2),
                parseInt(earnedOwnerStep1)
            );

            assert.isAbove(
                parseInt(earnedBobStep2),
                parseInt(earnedBobStep1)
            );
        });

        it("should earn rewards proportionally to staked amount multiple", async () => {

            await farm.makeDepositForUser(
                bob,
                ONE_TOKEN,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const stepTimeFrame = 1;
            const expectedDefaultEarn = 0;
            const rewardRate = await farm.rewardRateA();
            const earnPerStep = stepTimeFrame * rewardRate;

            const depositedByOwner = await farm.balanceOf(
                owner
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            assert.isAbove(
                parseInt(depositedByOwner),
                parseInt(depositedByBob)
            );

            assert.equal(
                depositedByOwner,
                depositedByBob * 2
            );

            const earnedInitalOwner = await farm.earnedA(
                owner
            );

            const earnedInitalBob = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedInitalOwner,
                earnedInitalBob * 2
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedOwnerStep1 = await farm.earnedA(
                owner
            );

            const earnedBobStep1 = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedOwnerStep1,
                earnedBobStep1 * 2
            );
        });
    });

    describe("Claiming functionality", () => {

        beforeEach(async () => {

            defaultDeposit = tokens("1");
            defaultRate = 10;

            const result = await setupScenario({
                approval: true,
                deposit: defaultDeposit
                // rate: defaultRate
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;
        });

        it("should reset userRewards mapping after claim to 0", async () => {

            const stakerAddess = owner;
            const expectedValue = 0;

            const userRewardsBeforeClaim = await farm.userRewardsA(
                stakerAddess
            );

            const earnedFromStart = await farm.earnedA(
                stakerAddess
            );

            assert.equal(
                parseInt(earnedFromStart),
                expectedValue
            );

            assert.equal(
                parseInt(userRewardsBeforeClaim),
                expectedValue
            );

            await farm.setRewardRates(
                defaultRate,
                defaultRate,
            );

            const timeJumpStep = 1;

            await time.increase(
                timeJumpStep
            );

            const earnedAfterStart = await farm.earnedA(
                stakerAddess
            );

            assert.isAbove(
                parseInt(earnedAfterStart),
                expectedValue
            );

            await time.increase(
                timeJumpStep
            );

            await farm.claimReward();

            const userRewardsAfterClaim = await farm.userRewardsA(
                stakerAddess
            );

            const earnAfterClaim = await farm.earnedA(
                stakerAddess
            );

            assert.isBelow(
                parseInt(earnAfterClaim),
                parseInt(earnedAfterStart)
            );

            assert.equal(
                parseInt(userRewardsAfterClaim),
                expectedValue
            );
        });

        it("should revert if nothing to claim", async () => {

            const stakerAddess = owner;
            const nonStakerAddress = bob;
            const timeJumpStep = 1;

            await farm.setRewardRates(
                defaultRate,
                defaultRate,
                {
                    from: stakerAddess
                }
            );

            await time.increase(
                timeJumpStep
            );

            await expectRevert(
                farm.claimReward(
                    {
                        from: nonStakerAddress
                    }
                ),
                "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
            );
        });

        it("should update lastUpdateTime value after claim", async () => {

            const stakerAddess = owner;
            const expectedValue = 0;

            const userRewardsBeforeClaim = await farm.userRewardsA(
                stakerAddess
            );

            const earnedFromStart = await farm.earnedA(
                stakerAddess
            );

            assert.equal(
                parseInt(earnedFromStart),
                expectedValue
            );

            assert.equal(
                parseInt(userRewardsBeforeClaim),
                expectedValue
            );

            await farm.setRewardRates(
                defaultRate,
                defaultRate
            );

            const timeJumpStep = 1;

            await time.increase(
                timeJumpStep
            );

            const earnedAfterStart = await farm.earnedA(
                stakerAddess
            );

            assert.isAbove(
                parseInt(earnedAfterStart),
                expectedValue
            );

            await time.increase(
                timeJumpStep
            );

            const lastUpdateTime = await farm.lastUpdateTime();
            await farm.claimReward();
            const lastUpdateTimeAfter = await farm.lastUpdateTime();

            assert.isAbove(
                lastUpdateTimeAfter.toNumber(),
                lastUpdateTime.toNumber()
            );
        });
    });

    describe("Exit functionality", () => {

        beforeEach(async () => {

            defaultTokenAmount = TWO_TOKENS;
            defaultRate = 10;

            const result = await setupScenario({
                approval: true,
                deposit: defaultTokenAmount,
                rate: defaultRate
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;
        });

        it("if all tokens unlock should not be able to exit until rewards are still available", async () => {

            const withdrawAccount = owner;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            await time.increase(
                defaultUnlockTime
            );

            await expectRevert(
                farm.exitFarm(
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: STILL_EARNING"
            );

            await time.increase(
                defaultDurationInSeconds + 1
            );

            await farm.exitFarm(
                {
                    from: withdrawAccount
                }
            );
        });

        it("if all tokens unlocked should not be able to exit as last farmer until rewards are still available", async () => {

            const withdrawAccount = owner;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            await time.increase(
                defaultUnlockTime
            );

            await expectRevert(
                farm.exitFarm(
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: STILL_EARNING"
            );

            await stakeToken.mint(
                defaultTokenAmount
            );

            await stakeToken.approve(
                farm.address,
                defaultTokenAmount
            );

            await farm.makeDepositForUser(
                bob,
                defaultTokenAmount,
                defaultUnlockTime
            );

            await time.increase(
                1
            );

            await farm.exitFarm(
                {
                    from: withdrawAccount
                }
            );
        });

        it("should not be able to exit if nothing to claim, perform withdraw instead", async () => {

            const withdrawAccount = owner;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.exitFarm(
                {
                    from: owner
                }
            );

            await time.increase(
                defaultDurationInSeconds + 1
            );

            await farm.claimReward(
                {
                    from: withdrawAccount
                }
            );

            await expectRevert(
                farm.exitFarm(
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
            );

            await farm.farmWithdraw(
                possibleWithdraw,
                {
                    from: withdrawAccount
                }
            );

            await expectRevert.unspecified(
                farm.farmWithdraw(
                    possibleWithdraw,
                    {
                        from: withdrawAccount
                    }
                )
            );
        });
    });

    describe("Recover token functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario();

            randomToken = await Token.new();
            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;
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

            await farm.recoverTokens(
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

            await rewardTokenA.transfer(
                farm.address,
                transferAmount
            );

            await expectRevert(
                farm.recoverTokens(
                    rewardTokenA.address,
                    transferAmount
                ),
                "TimeLockFarmV2Dual: INVALID_TOKEN"
            );
        });

        it("should not be able to recover rewardTokens from the contract", async () => {

            const transferAmount = ONE_TOKEN;

            await stakeToken.transfer(
                farm.address,
                transferAmount
            );

            await farm.recoverTokens(
                stakeToken.address,
                transferAmount
            );
        });
    });

    describe("Earn functionality with transfer", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            defaultTokenAmount = tokens("10000");
            defaultRewardRate = 100;

            await stakeToken.mint(
                defaultTokenAmount
            );

            await stakeToken.mint(
                defaultTokenAmount
            );

            await stakeToken.approve(
                farm.address,
                defaultTokenAmount
            );

            await stakeToken.approve(
                farm.address,
                defaultTokenAmount
            );
        });

        it("should issue tokens accordingly to staked balances even if transferred", async () => {

            const aliceDeposit = tokens("100");
            const bobDeposit = tokens("9900");

            const SECONDS_IN_DAY = 86400;
            const THREE_MONTHS = 90 * SECONDS_IN_DAY;

            await farm.makeDepositForUser(
                alice,
                aliceDeposit,
                defaultUnlockTime
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const supplyInFarmInitially = await rewardTokenA.balanceOf(
                farm.address
            );

            const depositedByAlice = await farm.balanceOf(
                alice
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            assert.isAbove(
                parseInt(depositedByBob),
                parseInt(depositedByAlice)
            );

            await time.increase(
                THREE_MONTHS
            );

            const earnedByBobBeforeTransfer = await farm.earnedA(
                bob
            );

            const earnedByAliceBeforeTransfer = await farm.earnedA(
                alice
            );

            assert.isAbove(
                parseInt(earnedByBobBeforeTransfer),
                parseInt(earnedByAliceBeforeTransfer)
            );

            await farm.transfer(
                alice,
                depositedByBob,
                {
                    from: bob
                }
            );

            const earnedByBobAfterTransfer = await farm.earnedA(
                bob
            );

            const earnedByAliceAfterTransfer = await farm.earnedA(
                alice
            );

            assert.isAbove(
                parseInt(earnedByBobAfterTransfer),
                parseInt(earnedByAliceAfterTransfer)
            );

            assert.equal(
                parseInt(earnedByBobAfterTransfer),
                parseInt(earnedByBobBeforeTransfer),
            );

            assert.equal(
                parseInt(earnedByAliceBeforeTransfer),
                parseInt(earnedByAliceAfterTransfer)
            );

            const depositedByAliceAfterTransfer = await farm.balanceOf(
                alice
            );

            const depositedByBobAfterTransfer = await farm.balanceOf(
                bob
            );

            assert.equal(
                parseInt(depositedByBobAfterTransfer),
                0
            );

            assert.equal(
                parseInt(depositedByAliceAfterTransfer),
                parseInt(depositedByAlice) + parseInt(depositedByBob)
            );

            const supplyInFarmBefore = await rewardTokenA.balanceOf(
                farm.address
            );

            await farm.farmWithdraw(
                tokens("10000"),
                {
                    from: alice
                }
            );

            await farm.claimReward(
                {
                    from: alice
                }
            );

            const alicesTransfer = await getLastEvent(
                "Transfer",
                rewardTokenA
            );

            await farm.claimReward(
                {
                    from: bob
                }
            );

            const bobsTransfer = await getLastEvent(
                "Transfer",
                rewardTokenA
            );

            const supplyAliceGot = await rewardTokenA.balanceOf(
                alice
            );

            assert.equal(
                supplyInFarmBefore.toString(),
                supplyInFarmInitially.toString()
            );

            assert.equal(
                alicesTransfer.from,
                farm.address
            );

            assert.equal(
                alicesTransfer.to,
                alice
            );

            assert.equal(
                alicesTransfer.value.toString(),
                earnedByAliceBeforeTransfer.toString()
            );

            assert.equal(
                alicesTransfer.value.toString(),
                supplyAliceGot.toString()
            );

            assert.equal(
                bobsTransfer.value.toString(),
                earnedByBobBeforeTransfer.toString()
            );

            assert.equal(
                bobsTransfer.value.toString(),
                earnedByBobAfterTransfer.toString()
            );
        });

        it("should issue tokens accordingly to staked balances even if transferred", async () => {

            const aliceDeposit = tokens("100");
            const bobDeposit = tokens("9900");

            const SECONDS_IN_DAY = 86400;
            const THREE_MONTHS = 90 * SECONDS_IN_DAY;

            await farm.makeDepositForUser(
                alice,
                aliceDeposit,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const supplyInFarmInitially = await rewardTokenA.balanceOf(
                farm.address
            );

            const depositedByAlice = await farm.balanceOf(
                alice
            );

            await time.increase(
                THREE_MONTHS
            );

            const earnedByAliceBeforeTransfer = await farm.earnedA(
                alice
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                defaultUnlockTime
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            const earnedByBobBeforeTransfer = await farm.earnedA(
                bob
            );

            await time.increase(
                defaultUnlockTime
            );

            await farm.transfer(
                alice,
                depositedByBob,
                {
                    from: bob
                }
            );

            await expectRevert(
                farm.claimReward(
                    {
                        from: bob
                    }
                ),
                "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
            );

            const earnedByBobAfterTransfer = await farm.earnedA(
                bob
            );

            const earnedByAliceAfterTransfer = await farm.earnedA(
                alice
            );

            assert.isAbove(
                parseInt(earnedByAliceAfterTransfer),
                parseInt(earnedByBobAfterTransfer)
            );

            assert.equal(
                parseInt(earnedByBobAfterTransfer),
                0
            );

            assert.equal(
                parseInt(earnedByAliceAfterTransfer),
                parseInt(earnedByAliceBeforeTransfer) + parseInt(earnedByBobBeforeTransfer)
            );

            const depositedByAliceAfterTransfer = await farm.balanceOf(
                alice
            );

            const depositedByBobAfterTransfer = await farm.balanceOf(
                bob
            );

            assert.equal(
                parseInt(depositedByBobAfterTransfer),
                0
            );

            assert.equal(
                parseInt(depositedByAliceAfterTransfer),
                parseInt(depositedByAlice) + parseInt(depositedByBob)
            );

            const supplyInFarmBefore = await rewardTokenA.balanceOf(
                farm.address
            );

            await farm.farmWithdraw(
                tokens("10000"),
                {
                    from: alice
                }
            );

            await farm.claimReward(
                {
                    from: alice
                }
            );

            await expectRevert(
                farm.claimReward(
                    {
                        from: bob
                    }
                ),
                "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
            );

            const supplyInFarmAfter = await rewardTokenA.balanceOf(
                farm.address
            );

            const supplyAliceGot = await rewardTokenA.balanceOf(
                alice
            );

            const { from, to, value } = await getLastEvent(
                "Transfer",
                rewardTokenA
            );

            assert.equal(
                supplyInFarmBefore.toString(),
                supplyInFarmInitially.toString()
            );

            assert.equal(
                from,
                farm.address
            );

            assert.equal(
                to,
                alice
            );

            assert.equal(
                value.toString(),
                supplyInFarmInitially.toString()
            );
        });

        it("should continue earning with higher/lower capacity after transfer", async () => {

            const aliceDeposit = tokens("5000");
            const bobDeposit = tokens("5000");
            const TIME_STEP = 100;

            await stakeToken.approve(
                farm.address,
                aliceDeposit
            );

            await farm.makeDepositForUser(
                alice,
                aliceDeposit,
                defaultUnlockTime
            );

            await stakeToken.approve(
                farm.address,
                bobDeposit
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const depositedByAlice = await farm.balanceOf(
                alice
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            assert.equal(
                parseInt(depositedByBob),
                parseInt(depositedByAlice)
            );

            await time.increase(
                defaultUnlockTime
            );

            const earnedByBobBeforeTransfer = await farm.earnedA(
                bob
            );

            const earnedByAliceBeforeTransfer = await farm.earnedA(
                alice
            );

            assert.equal(
                parseInt(earnedByBobBeforeTransfer),
                parseInt(earnedByAliceBeforeTransfer)
            );

            assert.isAbove(
                parseInt(earnedByBobBeforeTransfer),
                0
            );

            assert.isAbove(
                parseInt(earnedByAliceBeforeTransfer),
                0
            );

            await farm.transfer(
                alice,
                depositedByBob,
                {
                    from: bob
                }
            );

            await time.increase(
                TIME_STEP
            );

            const earnedByBobAfterTransfer = await farm.earnedA(
                bob
            );

            const earnedByAliceAfterTransfer = await farm.earnedA(
                alice
            );

            assert.equal(
                parseInt(earnedByBobBeforeTransfer),
                parseInt(earnedByBobAfterTransfer)
            );

            assert.isAbove(
                parseInt(earnedByAliceAfterTransfer),
                parseInt(earnedByAliceBeforeTransfer)
            );

            const totalEarnedByAliceExpected = parseInt(earnedByBobBeforeTransfer)
                + parseInt(earnedByAliceBeforeTransfer)
                + parseInt(earnedByAliceBeforeTransfer);

            assert.equal(
                parseInt(earnedByAliceAfterTransfer),
                totalEarnedByAliceExpected
            );

            const earnedByAliceAfterTransferDelta = parseInt(earnedByAliceAfterTransfer)
                - parseInt(earnedByAliceBeforeTransfer);

            assert.equal(
                earnedByAliceAfterTransferDelta,
                earnedByAliceBeforeTransfer * 2
            );
        });

        it("should issue tokens accordingly to staked balances even if claimed and transferred", async () => {

            const aliceDeposit = tokens("100");
            const bobDeposit = tokens("9900");

            const SECONDS_IN_DAY = 86400;
            const THREE_MONTHS = 90 * SECONDS_IN_DAY;

            await stakeToken.mint(
                aliceDeposit
            );

            await stakeToken.mint(
                bobDeposit
            );

            await stakeToken.approve(
                farm.address,
                aliceDeposit
            );

            await farm.makeDepositForUser(
                alice,
                aliceDeposit,
                defaultUnlockTime
            );

            await stakeToken.approve(
                farm.address,
                bobDeposit
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                defaultUnlockTime
            );

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const supplyInFarmInitially = await rewardTokenA.balanceOf(
                farm.address
            );

            const depositedByAlice = await farm.balanceOf(
                alice
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            assert.isAbove(
                parseInt(depositedByBob),
                parseInt(depositedByAlice)
            );

            await time.increase(
                THREE_MONTHS
            );

            const earnedByBobBeforeTransfer = await farm.earnedA(
                bob
            );

            const earnedByAliceBeforeTransfer = await farm.earnedA(
                alice
            );

            assert.isAbove(
                parseInt(earnedByBobBeforeTransfer),
                parseInt(earnedByAliceBeforeTransfer)
            );

            await farm.claimReward(
                {
                    from: bob
                }
            );

            const bobsClaim = await getLastEvent(
                "Transfer",
                rewardTokenA
            );

            assert.equal(
                bobsClaim.from,
                farm.address
            );

            assert.equal(
                bobsClaim.to,
                bob
            );

            assert.equal(
                bobsClaim.value.toString(),
                earnedByBobBeforeTransfer
            );

            await farm.transfer(
                alice,
                depositedByBob,
                {
                    from: bob
                }
            );

            const earnedByBobAfterTransfer = await farm.earnedA(
                bob
            );

            const earnedByAliceAfterTransfer = await farm.earnedA(
                alice
            );

            assert.isAbove(
                parseInt(earnedByAliceAfterTransfer),
                parseInt(earnedByBobAfterTransfer)
            );

            assert.equal(
                parseInt(earnedByBobAfterTransfer),
                0
            );

            assert.equal(
                parseInt(earnedByAliceAfterTransfer),
                parseInt(earnedByAliceBeforeTransfer)
            );

            const depositedByAliceAfterTransfer = await farm.balanceOf(
                alice
            );

            const depositedByBobAfterTransfer = await farm.balanceOf(
                bob
            );

            assert.equal(
                parseInt(depositedByBobAfterTransfer),
                0
            );

            assert.equal(
                parseInt(depositedByAliceAfterTransfer),
                parseInt(depositedByAlice) + parseInt(depositedByBob)
            );

            await farm.farmWithdraw(
                tokens("10000"),
                {
                    from: alice
                }
            );

            await farm.claimReward(
                {
                    from: alice
                }
            );

            await expectRevert(
                farm.claimReward(
                    {
                        from: bob
                    }
                ),
                "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
            );

            const supplyInFarmAfter = await rewardTokenA.balanceOf(
                farm.address
            );

            const supplyAliceGot = await rewardTokenA.balanceOf(
                alice
            );

            const aliceTransfer = await getLastEvent(
                "Transfer",
                rewardTokenA
            );

            assert.equal(
                aliceTransfer.from,
                farm.address
            );

            assert.equal(
                aliceTransfer.to,
                alice
            );

            assert.equal(
                aliceTransfer.value.toString(),
                earnedByAliceBeforeTransfer
            );

            assert.equal(
                aliceTransfer.value.toString(),
                earnedByAliceAfterTransfer
            );
        });
    });
});
