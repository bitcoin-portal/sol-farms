const Token = artifacts.require("TestToken");
const Farm = artifacts.require("TimeLockFarmV2Dual");
const { expectRevert, time } = require('@openzeppelin/test-helpers');
const { assert } = require('chai');

require("./utils");

const _BN = web3.utils.BN;
const BN = (value) => {
    return new _BN(value)
}

const tokens = (value) => {
    return web3.utils.toWei(value);
}

const ONE_TOKEN = tokens("1");
const TWO_TOKENS = tokens("2");

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

contract("SimpleFarm", ([
    owner,
    alice,
    bob,
    chad,
    random
]) => {

    const setupScenario = async (inputParams = {}) => {

        stakeToken = await Token.new();
        rewardTokenA = await Token.new();
        rewardTokenB = await Token.new();

        defaultApprovalAmount = 100;
        defaultDurationInSeconds = 300;

        farm = await Farm.new(
            stakeToken.address,
            rewardTokenA.address,
            rewardTokenB.address,
            defaultDurationInSeconds
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
                alice,
                inputParams.deposit,
                0
            );
        }

        if (inputParams.rateA || inputParams.rateB) {
            await farm.setRewardRates(
                inputParams.rateA,
                inputParams.rateB
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

            const rTokenA = await farm.rewardTokenA();
            const rTokenB = await farm.rewardTokenB();

            assert.equal(
                rTokenA,
                rewardTokenA.address
            );

            assert.equal(
                rTokenB,
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

            assert.equal(
                managerAddress,
                owner
            );
        });

        it("should have correct perTokenStored value", async () => {

            const perTokenStoredA = await farm.perTokenStoredA();
            const perTokenStoredB = await farm.perTokenStoredB();

            const expectedDefaultValue = 0;

            assert.equal(
                perTokenStoredA,
                expectedDefaultValue
            );

            assert.equal(
                perTokenStoredB,
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
                defaultDurationValue,
                defaultDurationInSeconds
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

        it("should have correct unlockable amount based on time", async () => {

            const defaultDuration = await farm.rewardDuration();
            const expectedDefaultDuration = defaultDurationInSeconds;

            assert.equal(
                defaultDuration,
                expectedDefaultDuration
            );

            await farm.makeDepositForUser(
                alice,
                10,
                0
            );

            const unlockableAfterFirst = await farm.unlockable(
                alice
            );

            console.log(unlockableAfterFirst.toString(), 'unlockableAfterFirst');

            await farm.makeDepositForUser(
                alice,
                13,
                10000
            );

            const unlockableAfterSecond = await farm.unlockable(
                alice
            );

            console.log(unlockableAfterSecond.toString(), 'unlockableAfterSecond');

            await time.increase(
                defaultDuration + 1
            );

            const unlockableAfterTime = await farm.unlockable(
                alice
            );

            console.log(unlockableAfterTime.toString(), 'unlockableAfterTime');

            await time.increase(
                defaultDuration + 1
            );

            const unlockableAfterTime2 = await farm.unlockable(
                alice
            );

            console.log(unlockableAfterTime2.toString(), 'unlockableAfterTime2');


            await time.increase(
                defaultDuration + 1
            );

            const unlockableAfterTime3 = await farm.unlockable(
                alice
            );

            console.log(unlockableAfterTime3.toString(), 'unlockableAfterTime2');

            await time.increase(
                defaultDuration + 1
            );

            const unlockableAfterTime4 = await farm.unlockable(
                alice
            );

            console.log(unlockableAfterTime4.toString(), 'unlockableAfterTime2');

            await time.increase(
                defaultDuration + 1
            );

            const unlockableAfterTime5 = await farm.unlockable(
                alice
            );

            console.log(unlockableAfterTime5.toString(), 'unlockableAfterTime2');
        });

        it("should not be able to change farm duration during distribution", async () => {

            const defaultDuration = await farm.rewardDuration();
            const expectedDefaultDuration = defaultDurationInSeconds;
            const newDurationWrongValue = 100;

            assert.equal(
                defaultDuration,
                expectedDefaultDuration
            );

            await farm.makeDepositForUser(
                alice,
                10,
                0
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
                alice,
                ONE_TOKEN,
                0
            );

            await expectRevert(
                farm.setRewardRates(
                    0,
                    0
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
            const initialRateA = 10;
            const initialRateB = 20;
            const expectedInitialValue = 0;

            assert.equal(
                initialPeriod,
                expectedInitialValue
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                initialRateA,
                initialRateB
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

            const perTokenStoredDefaultA = await farm.perTokenStoredA();
            const perTokenStoredDefaultB = await farm.perTokenStoredB();
            const expectedDefaultValue = 0;
            const initialRateA = 10;
            const initialRateB = 20;

            assert.equal(
                perTokenStoredDefaultA,
                expectedDefaultValue
            );

            assert.equal(
                perTokenStoredDefaultB,
                expectedDefaultValue
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                initialRateA,
                initialRateB
            );

            await time.increase(
                1
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            const perTokenStoredNewA = await farm.perTokenStoredA();
            const perTokenStoredNewB = await farm.perTokenStoredB();

            assert.isAbove(
                parseInt(perTokenStoredNewA),
                parseInt(perTokenStoredDefaultA)
            );

            assert.isAbove(
                parseInt(perTokenStoredNewB),
                parseInt(perTokenStoredDefaultB)
            );
        });

        it("should emit correct RewardAdded event", async () => {

            const initialRateA = 10;
            const initialRateB = 20;
            const rewardDuration = await farm.rewardDuration();

            const expectedAmountA = rewardDuration
                * initialRateA;

            const expectedAmountB = rewardDuration
                * initialRateB;

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                initialRateA,
                initialRateB
            );

            const rewardEvent = await getLastEvent(
                "RewardAdded",
                farm
            );

            assert.equal(
                expectedAmountA,
                rewardEvent.tokenAmountA
            );

            assert.equal(
                expectedAmountB,
                rewardEvent.tokenAmountB
            );
        });

        it("manager should be able to set rewards rate only if stakers exist", async () => {

            const newRewardRateA = 10;
            const newRewardRateB = 20;

            const expectedNewRateA = newRewardRateA;
            const expectedNewRateB = newRewardRateB;

            await expectRevert(
                farm.setRewardRates(
                    newRewardRateA,
                    newRewardRateB
                ),
                "TimeLockFarmV2Dual: NO_STAKERS"
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                newRewardRateA,
                newRewardRateB
            );

            const rateAfterChangedA = await farm.rewardRateA();
            const rateAfterChangedB = await farm.rewardRateB();

            assert.equal(
                rateAfterChangedA,
                expectedNewRateA
            );

            assert.equal(
                rateAfterChangedB,
                expectedNewRateB
            );
        });

        it("manager should fund the farm during reward rate announcement", async () => {

            const newRewardRateA = 10;
            const newRewardRateB = 20;

            const expectedDuration = await farm.rewardDuration();
            const currentManager = await farm.managerAddress();

            const expectedTransferAmountA = newRewardRateA
                * expectedDuration;

            const expectedTransferAmountB = newRewardRateB
                * expectedDuration;

            const managerBalanceA = await rewardTokenA.balanceOf(
                currentManager
            );

            const managerBalanceB = await rewardTokenB.balanceOf(
                currentManager
            );

            assert.isAbove(
                parseInt(managerBalanceA),
                expectedTransferAmountA
            );

            assert.isAbove(
                parseInt(managerBalanceB),
                expectedTransferAmountB
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                newRewardRateA,
                newRewardRateB
            );

            const transferDataA = await getLastEvent(
                "Transfer",
                rewardTokenA
            );

            const transferDataB = await getLastEvent(
                "Transfer",
                rewardTokenB
            );

            assert.equal(
                transferDataA.from,
                currentManager
            );

            assert.equal(
                transferDataA.to,
                farm.address
            );

            assert.equal(
                transferDataA.value,
                expectedTransferAmountA
            );

            assert.equal(
                transferDataB.from,
                currentManager
            );

            assert.equal(
                transferDataB.to,
                farm.address
            );

            assert.equal(
                transferDataB.value,
                expectedTransferAmountB
            );

            const afterTransferManagerA = await rewardTokenA.balanceOf(
                currentManager
            );

            const afterTransferManagerB = await rewardTokenB.balanceOf(
                currentManager
            );

            const afterTransferFarmA = await rewardTokenA.balanceOf(
                farm.address
            );

            const afterTransferFarmB = await rewardTokenB.balanceOf(
                farm.address
            );

            assert.equal(
                managerBalanceA,
                parseInt(afterTransferManagerA) + parseInt(expectedTransferAmountA)
            );

            assert.equal(
                managerBalanceB,
                parseInt(afterTransferManagerB) + parseInt(expectedTransferAmountB)
            );

            assert.equal(
                expectedTransferAmountA,
                afterTransferFarmA
            );

            assert.equal(
                expectedTransferAmountB,
                afterTransferFarmB
            );
        });

        it("manager should be able to increase rate any time", async () => {

            const initialRateA = 10;
            const initialRateB = 10;

            const increasedRewardRateA = 11;
            const increasedRewardRateB = 11;

            assert.isAbove(
                increasedRewardRateA,
                initialRateA
            );

            assert.isAbove(
                increasedRewardRateB,
                initialRateB
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                initialRateA,
                initialRateB
            );

            const rateBeforeChangedA = await farm.rewardRateA();
            const rateBeforeChangedB = await farm.rewardRateB();

            assert.equal(
                rateBeforeChangedA,
                initialRateA
            );

            assert.equal(
                rateBeforeChangedB,
                initialRateB
            );

            await farm.setRewardRates(
                increasedRewardRateA,
                increasedRewardRateB
            );

            const rateAfterChangedA = await farm.rewardRateA();
            const rateAfterChangedB = await farm.rewardRateB();

            assert.equal(
                rateAfterChangedA,
                increasedRewardRateA
            );

            assert.equal(
                rateAfterChangedB,
                increasedRewardRateB
            );
        });

        it("manager should be able to decrease rate only after distribution finished", async () => {

            const initialRateA = 10;
            const initialRateB = 10;

            const decreasedRewardRateA = 9;
            const decreasedRewardRateB = 9;

            assert.isBelow(
                decreasedRewardRateA,
                initialRateA
            );

            assert.isBelow(
                decreasedRewardRateB,
                initialRateB
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                initialRateA,
                initialRateB
            );

            const rateAfterChangedA = await farm.rewardRateA();
            const rateAfterChangedB = await farm.rewardRateB();

            assert.equal(
                rateAfterChangedB,
                initialRateB
            );

            assert.equal(
                rateAfterChangedA,
                initialRateA
            );

            await expectRevert(
                farm.setRewardRates(
                    decreasedRewardRateA,
                    decreasedRewardRateB
                ),
                "TimeLockFarmV2Dual: RATE_A_CANT_DECREASE"
            );

            await expectRevert(
                farm.setRewardRates(
                    initialRateA,
                    decreasedRewardRateB
                ),
                "TimeLockFarmV2Dual: RATE_B_CANT_DECREASE"
            );

            const currentDuration = await farm.rewardDuration();

            await time.increase(
                currentDuration
            );

            await farm.setRewardRates(
                decreasedRewardRateA,
                decreasedRewardRateB
            );

            const newRateA = await farm.rewardRateA();
            const newRateB = await farm.rewardRateB();

            assert.equal(
                parseInt(newRateA),
                decreasedRewardRateA
            );

            assert.equal(
                parseInt(newRateB),
                decreasedRewardRateB
            );
        });
    });

    describe("Deposit initial functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;
        });

        it("should transfer correct amount from admin to farm", async () => {

            const depositValue = ONE_TOKEN;
            const depositAddress = bob;

            const balanceBefore = await stakeToken.balanceOf(
                depositAddress
            );

            const balanceBeforeAdmin = await stakeToken.balanceOf(
                owner
            );

            await farm.makeDepositForUser(
                depositAddress,
                depositValue,
                0
            );

            const balanceAfter = await stakeToken.balanceOf(
                depositAddress
            );

            const balanceAfterAdmin = await stakeToken.balanceOf(
                owner
            );

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore)
            );

            assert.equal(
                parseInt(balanceAfterAdmin),
                parseInt(balanceBeforeAdmin) - parseInt(depositValue)
            );
        });

        it("should increase the balance of the wallet thats deposit is done for", async () => {

            const depositAmount = ONE_TOKEN;

            const supplyBefore = await farm.balanceOf(
                alice
            );

            await farm.makeDepositForUser(
                alice,
                depositAmount,
                0
            );

            const supplyAfter = await farm.balanceOf(
                alice
            );

            assert.equal(
                parseInt(supplyAfter),
                parseInt(supplyBefore) + parseInt(depositAmount)
            );
        });

        it("should add the correct amount to the total supply", async () => {

            const supplyBefore = await farm.balanceOf(
                alice
            );

            const depositAmount = ONE_TOKEN;

            await farm.makeDepositForUser(
                alice,
                depositAmount,
                0
            );

            const totalSupply = await farm.totalSupply();

            assert.equal(
                totalSupply.toString(),
                (BN(supplyBefore).add(BN(depositAmount))).toString()
            );
        });

        it("should add the correct amount to the total supply squared", async () => {

            const supplyBefore = await farm.balanceOf(
                alice
            );

            const depositAmount = ONE_TOKEN;

            await farm.makeDepositForUser(
                alice,
                depositAmount,
                0
            );

            const totalSupplySQR = await farm.totalSupplySQR();

            assert.equal(
                totalSupplySQR.toString(),
                (BN(supplyBefore).add(BN(Math.sqrt(depositAmount)))).toString()
            );
        });

        it("should not be able to deposit if not approved enough", async () => {

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
                    alice,
                    depositAmount,
                    0
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
                    from: bob
                }
            );

            await stakeToken.approve(
                farm.address,
                approvalValue,
                {
                    from: owner
                }
            );

            await farm.makeDepositForUser(
                alice,
                ONE_TOKEN,
                0
            );

            await farm.approve(
                bob,
                approvalValue,
                {
                    from: alice
                }
            );

            const allowanceValueBefore = await farm.allowance(
                alice,
                bob
            );

            assert.equal(
                MAX_VALUE.toString(),
                allowanceValueBefore.toString()
            );

            await farm.transferFrom(
                alice,
                bob,
                transferValue,
                {
                    from: bob
                }
            );

            const allowanceValueAfter = await farm.allowance(
                alice,
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
                alice,
                defaultTokenAmount,
                0,
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
                ZERO_ADDRESS
            );

            assert.equal(
                to,
                alice
            );
        });

        it("should emit correct event when burning receipt tokens (during withdraw)", async () => {

            const depositor = owner;

            await farm.makeDepositForUser(
                alice,
                defaultTokenAmount,
                0,
                {
                    from: depositor
                }
            );

            await farm.farmWithdraw(
                defaultTokenAmount,
                {
                    from: alice
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
                alice
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
            rewardTokenB = result.rewardTokenB;
            farm = result.farm;

            defaultTokenAmount = TWO_TOKENS;

            await farm.makeDepositForUser(
                alice,
                defaultTokenAmount,
                0
            );
        });

        it("should transfer correct amount from walletA to walletB", async () => {

            const transferValue = defaultTokenAmount;
            const balanceBefore = await farm.balanceOf(bob);

            await farm.transfer(
                bob,
                transferValue,
                {
                    from: alice
                }
            );

            const balanceAfter = await farm.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await farm.balanceOf(
                alice
            );

            await expectRevert.unspecified(
                farm.transfer(
                    bob,
                    balanceBefore.toString() + "1",
                    {
                        from: alice
                    }
                )
            );
        });

        it("should reduce wallets balance after transfer", async () => {

            const transferValue = defaultTokenAmount;
            const balanceBefore = await farm.balanceOf(
                alice
            );

            await farm.transfer(
                bob,
                transferValue,
                {
                    from: alice
                }
            );

            const balanceAfter = await farm.balanceOf(
                alice
            );

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should emit correct Transfer event", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecepient = bob;

            await farm.transfer(
                expectedRecepient,
                transferValue,
                {
                    from: alice
                }
            );

            const { from, to, value } = await getLastEvent(
                "Transfer",
                farm
            );

            assert.equal(
                from,
                alice
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

        it("should update the balance of the recipient when using transferFrom", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecipient = bob;
            const balanceBefore = await farm.balanceOf(bob);

            await farm.approve(
                owner,
                transferValue,
                {
                    from: alice
                }
            );

            await farm.transferFrom(
                alice,
                expectedRecipient,
                transferValue
            );

            const balanceAfter = await farm.balanceOf(
                expectedRecipient
            );

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should deduct from the balance of the sender when using transferFrom", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecipient = bob;
            const balanceBefore = await farm.balanceOf(alice);

            await farm.approve(
                owner,
                transferValue,
                {
                    from: alice
                }
            );

            await farm.transferFrom(
                alice,
                expectedRecipient,
                transferValue
            );

            const balanceAfter = await farm.balanceOf(
                alice
            );

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
                    transferValue,
                    {
                        from: alice
                    }
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
                alice,
                defaultTokenAmount,
                0
            );
        });

        it("should reduce the balance of the wallet thats withrawing the stakeTokens", async () => {

            const withdrawAmount = ONE_TOKEN;
            const withdrawAccount = alice;

            const supplyBefore = await farm.balanceOf(
                withdrawAccount
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
            const withdrawAccount = alice;

            const supplyBefore = await farm.balanceOf(
                withdrawAccount
            );

            await farm.farmWithdraw(
                withdrawAmount,
                {
                    from: withdrawAccount
                }
            );

            const totalSupply = await farm.totalSupply();

            assert.equal(
                totalSupply,
                supplyBefore - withdrawAmount
            );
        });

        it("should deduct the correct amount from the total supply squared", async () => {

            const withdrawAmount = ONE_TOKEN;
            const withdrawAccount = alice;

            const supplyBefore = await farm.balanceOf(
                withdrawAccount
            );

            await farm.farmWithdraw(
                withdrawAmount,
                {
                    from: withdrawAccount
                }
            );

            const totalSupply = await farm.totalSupplySQR();

            assert.equal(
                totalSupply.toString(),
                parseInt(Math.sqrt(supplyBefore) - Math.sqrt(withdrawAmount))
            );
        });

        it("should deduct the correct amount from the total supply squared", async () => {

            const withdrawAmount = ONE_TOKEN;
            const withdrawAccount = alice;

            const initialTotalSupplySQR = await farm.totalSupplySQR();

            await farm.farmWithdraw(
                withdrawAmount,
                {
                    from: withdrawAccount
                }
            );

            const updatedTotalSupplySQR = await farm.totalSupplySQR();

            assert.equal(
                updatedTotalSupplySQR.toString(),
                parseInt(initialTotalSupplySQR - Math.sqrt(withdrawAmount))
            );
        });

        it("should be able to withdraw as last farmer even if rewards are still available", async () => {

            await farm.makeDepositForUser(
                alice,
                defaultTokenAmount,
                0
            );

            await farm.setRewardRates(
                10,
                10
            );

            const withdrawAccount = alice;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            await farm.farmWithdraw(
                possibleWithdraw,
                {
                    from: withdrawAccount
                }
            );

            await farm.makeDepositForUser(
                alice,
                defaultTokenAmount,
                0
            );

            await farm.farmWithdraw(
                defaultTokenAmount,
                {
                    from: alice
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

        it("should have correct owner address based on deployment wallet", async () => {

            const expectedAddress = alice;

            const newFarm = await Farm.new(
                stakeToken.address,
                rewardTokenA.address,
                rewardTokenB.address,
                defaultDurationInSeconds,
                {
                    from: expectedAddress
                }
            );

            const ownerAddress = await newFarm.ownerAddress();

            assert.equal(
                expectedAddress,
                ownerAddress
            );
        });

        it("should revert if new owner announced is ZERO_ADDRESS", async () => {

            const wrongAddress = "0x0000000000000000000000000000000000000000";
            const rightAddress = "0x0000000000000000000000000000000000000001";

            await expectRevert(
                farm.proposeNewOwner(
                    wrongAddress,
                    {
                        from: owner
                    }
                ),
                "TimeLockFarmV2Dual: WRONG_ADDRESS"
            );

            await farm.proposeNewOwner(
                rightAddress,
                {
                    from: owner
                }
            );

            const propsoedOwner = await farm.proposedOwner();

            assert.equal(
                rightAddress,
                propsoedOwner
            );
        });

        it("should be able to announce new owner only by current owner", async () => {

            const expectedCurrentOwner = owner;
            const newProposedOwner = bob;
            const wrongOwner = alice;

            const currentOwner = await farm.ownerAddress();

            assert.equal(
                currentOwner,
                expectedCurrentOwner
            );

            await expectRevert(
                farm.proposeNewOwner(
                    newProposedOwner,
                    {
                        from: wrongOwner
                    }
                ),
                "TimeLockFarmV2Dual: INVALID_OWNER"
            );

            await farm.proposeNewOwner(
                newProposedOwner,
                {
                    from: currentOwner
                }
            );

            assert.notEqual(
                wrongOwner,
                currentOwner
            );

            assert.notEqual(
                currentOwner,
                newProposedOwner
            );
        });

        it("should be able to claim ownership only by proposed wallet", async () => {

            const expectedCurrentOwner = owner;
            const newProposedOwner = bob;
            const wrongOwner = alice;

            const currentOwner = await farm.ownerAddress();

            assert.equal(
                currentOwner,
                expectedCurrentOwner
            );

            await expectRevert(
                farm.proposeNewOwner(
                    newProposedOwner,
                    {
                        from: wrongOwner
                    }
                ),
                "TimeLockFarmV2Dual: INVALID_OWNER"
            );

            await farm.proposeNewOwner(
                newProposedOwner,
                {
                    from: currentOwner
                }
            );

            assert.notEqual(
                wrongOwner,
                currentOwner
            );

            assert.notEqual(
                currentOwner,
                newProposedOwner
            );

            await expectRevert(
                farm.claimOwnership(
                    {
                        from: currentOwner
                    }
                ),
                "TimeLockFarmV2Dual: INVALID_CANDIDATE"
            );

            await expectRevert(
                farm.claimOwnership(
                    {
                        from: wrongOwner
                    }
                ),
                "TimeLockFarmV2Dual: INVALID_CANDIDATE"
            );

            await farm.claimOwnership(
                {
                    from: newProposedOwner
                }
            );

            const newOwnerAfterChange = await farm.ownerAddress();

            assert.equal(
                newProposedOwner,
                newOwnerAfterChange
            );
        });

        it("should produce correct event during ownership change", async () => {

            const expectedCurrentOwner = owner;
            const newProposedOwner = bob;

            const currentOwner = await farm.ownerAddress();

            await farm.proposeNewOwner(
                newProposedOwner,
                {
                    from: currentOwner
                }
            );

            await farm.claimOwnership(
                {
                    from: newProposedOwner
                }
            );

            const newOwnerAfterChange = await farm.ownerAddress();

            assert.equal(
                newProposedOwner,
                newOwnerAfterChange
            );

            const eventData = await getLastEvent(
                "OwnerChanged",
                farm
            );

            assert.equal(
                eventData.newOwner,
                newOwnerAfterChange
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

            const expectedAddress = alice;

            const newFarm = await Farm.new(
                stakeToken.address,
                rewardTokenA.address,
                rewardTokenB.address,
                defaultDurationInSeconds,
                {
                    from: expectedAddress
                }
            );

            const managerAddress = await newFarm.managerAddress();

            assert.equal(
                expectedAddress,
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

            rewardTokenA = result.rewardTokenA;
            rewardTokenB = result.rewardTokenB;

            farm = result.farm;

            defaultTokenAmount = TWO_TOKENS;
            defaultRewardRate = 10;

            await farm.makeDepositForUser(
                alice,
                defaultTokenAmount,
                0
            );

            await stakeToken.approve(
                farm.address,
                tokens("10000000000000")
            );

            await rewardTokenA.approve(
                farm.address,
                tokens("10000000000000")
            );

            await rewardTokenB.approve(
                farm.address,
                tokens("10000000000000")
            );
        });

        it("should earn rewards proportionally to stake time", async () => {

            await farm.setRewardRates(
                tokens("10"),
                tokens("10")
            );

            const stepTimeFrame = 1;
            const expectedDefaultEarn = 0;

            const rewardRateA = await farm.rewardRateA();
            const rewardRateB = await farm.rewardRateB();

            // console.log(rewardRateB.toString(), 'rewardRateB');
            // console.log(stepTimeFrame.toString(), 'stepTimeFrame');

            const earnedInitalA = await farm.earnedA(
                alice
            );

            const earnedInitalB = await farm.earnedB(
                alice
            );

            const res = rewardRateB * stepTimeFrame;

            // console.log(res.toString(), 'res');
            // console.log(earnedInitalB.toString(), 'earnedInitalB');

            const earnPerStepA = stepTimeFrame * rewardRateA;
            const earnPerStepB = stepTimeFrame * rewardRateB;

            assert.equal(
                parseInt(earnedInitalA),
                parseInt(expectedDefaultEarn)
            );

            assert.equal(
                parseInt(earnedInitalB),
                parseInt(expectedDefaultEarn)
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedStep1A = await farm.earnedA(
                alice
            );

            const totalSQR = await farm.totalSupplySQR();
            const balanceOfAlice = await farm.balanceOf(
                alice
            );

            assert.equal(
                parseInt(totalSQR),
                parseInt(Math.sqrt(balanceOfAlice))
            );

            const earnedStep1B = await farm.earnedB(
                alice
            );

            const rewardPerTokenA = await farm.rewardPerTokenA();
            const rewardPerTokenB = await farm.rewardPerTokenB();

            // console.log(rewardPerTokenA.toString(), 'rewardPerTokenA');
            // console.log(rewardPerTokenB.toString(), 'rewardPerTokenB');
            // console.log(earnedStep1B.toString(), 'earnedStep1B');

            assert.isAtLeast(
                parseInt(earnedStep1A),
                earnPerStepA * 1
            );

            assert.equal(
                earnedStep1A.toString(),
                (rewardPerTokenA * balanceOfAlice / 1E18).toString()
            );

            assert.isAtLeast(
                parseInt(earnedStep1B),
                earnPerStepB * 1
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedStep2A = await farm.earnedA(
                alice
            );

            const earnedStep2B = await farm.earnedB(
                alice
            );

            assert.isAtLeast(
                parseInt(earnedStep2A),
                earnPerStepA * 2
            );

            assert.isAtLeast(
                parseInt(earnedStep2B),
                earnPerStepB * 2
            );
        });

        // @TODO: duplicate for B
        it("should earn rewardA proportionally to staked amount single", async () => {

            await farm.makeDepositForUser(
                bob,
                defaultTokenAmount,
                0
            );

            await farm.setRewardRates(
                tokens("10"),
                tokens("10")
            );

            const stepTimeFrame = 1;
            const expectedDefaultEarn = 0;

            const depositedByAlice = await farm.balanceOf(
                alice
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            assert.equal(
                depositedByAlice.toString(),
                depositedByBob.toString()
            );

            const earnedInitalAlice = await farm.earnedA(
                alice
            );

            const earnedInitalBob = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedInitalAlice.toString(),
                earnedInitalBob.toString()
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedAliceStep1 = await farm.earnedA(
                alice
            );

            const earnedBobStep1 = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedAliceStep1.toString(),
                earnedBobStep1.toString()
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedAliceStep2 = await farm.earnedA(
                alice
            );

            const earnedBobStep2 = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedAliceStep2.toString(),
                earnedBobStep2.toString()
            );

            assert.isAbove(
                parseInt(earnedAliceStep2),
                parseInt(earnedAliceStep1)
            );

            assert.isAbove(
                parseInt(earnedBobStep2),
                parseInt(earnedBobStep1)
            );
        });

        // @TODO: duplicate for B
        it("should earn rewards proportionally to staked amount multiple", async () => {

            await farm.makeDepositForUser(
                bob,
                ONE_TOKEN,
                0
            );

            await farm.setRewardRates(
                defaultRewardRate,
                defaultRewardRate
            );

            const stepTimeFrame = 1;
            const expectedDefaultEarn = 0;

            const rewardRate = await farm.rewardRateA();

            const earnPerStep = stepTimeFrame * rewardRate;

            const depositedByAlice = await farm.balanceOf(
                alice
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            assert.isAbove(
                parseInt(depositedByAlice),
                parseInt(depositedByBob)
            );

            assert.equal(
                depositedByAlice,
                depositedByBob * 2
            );

            const earnedInitalAlice = await farm.earnedA(
                alice
            );

            const earnedInitalBob = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedInitalAlice,
                earnedInitalBob * 2
            );

            await time.increase(
                stepTimeFrame
            );

            const earnedAliceStep1 = await farm.earnedA(
                alice
            );

            const earnedBobStep1 = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedAliceStep1,
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
            rewardToken = result.rewardToken;
            farm = result.farm;
        });

        it("should reset userRewards mapping after claim to 0", async () => {

            const stakerAddess = alice;
            const expectedValue = 0;

            const userRewardsBeforeClaimA = await farm.userRewardsA(
                stakerAddess
            );

            const userRewardsBeforeClaimB = await farm.userRewardsB(
                stakerAddess
            );

            const earnedFromStartA = await farm.earnedA(
                stakerAddess
            );

            const earnedFromStartB = await farm.earnedB(
                stakerAddess
            );

            assert.equal(
                parseInt(earnedFromStartA),
                expectedValue
            );

            assert.equal(
                parseInt(earnedFromStartB),
                expectedValue
            );

            assert.equal(
                parseInt(userRewardsBeforeClaimA),
                expectedValue
            );

            assert.equal(
                parseInt(userRewardsBeforeClaimB),
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

            const earnedAfterStartA = await farm.earnedA(
                stakerAddess
            );

            const earnedAfterStartB = await farm.earnedA(
                stakerAddess
            );

            assert.isAbove(
                parseInt(earnedAfterStartA),
                expectedValue
            );

            assert.isAbove(
                parseInt(earnedAfterStartB),
                expectedValue
            );

            await time.increase(
                timeJumpStep
            );

            await farm.claimReward(
                {
                    from: alice
                }
            );

            const userRewardsAfterClaimA = await farm.userRewardsA(
                stakerAddess
            );

            const userRewardsAfterClaimB = await farm.userRewardsB(
                stakerAddess
            );

            const earnAfterClaimA = await farm.earnedA(
                stakerAddess
            );

            const earnAfterClaimB = await farm.earnedB(
                stakerAddess
            );

            assert.isBelow(
                parseInt(earnAfterClaimA),
                parseInt(earnedAfterStartA)
            );

            assert.isBelow(
                parseInt(earnAfterClaimB),
                parseInt(earnedAfterStartB)
            );

            assert.equal(
                parseInt(userRewardsAfterClaimA),
                expectedValue
            );

            assert.equal(
                parseInt(userRewardsAfterClaimB),
                expectedValue
            );
        });

        it("should revert if nothing to claim", async () => {

            const nonStakerAddress = bob;
            const timeJumpStep = 1;

            await farm.setRewardRates(
                defaultRate,
                defaultRate
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

        // @TODO: make same for token B
        it("should update lastUpdateTime value after claim", async () => {

            const stakerAddess = alice;
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
            await farm.claimReward(
                {
                    from: alice
                }
            );
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
                rateA: defaultRate,
                rateB: defaultRate
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;
        });

        it("should be able to exit even if rewards are still available", async () => {

            const withdrawAccount = alice;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            assert.isAbove(
                parseInt(possibleWithdraw),
                0
            );

            await farm.exitFarm(
                {
                    from: withdrawAccount
                }
            );

            await time.increase(
                defaultDurationInSeconds + 1
            );

            await expectRevert(
                farm.exitFarm(
                    {
                        from: withdrawAccount
                    }
                ),
                "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
            );
        });

        it("should be able to exit as last farmer even if rewards are still available", async () => {

            const withdrawAccount = alice;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            assert.isAbove(
                parseInt(possibleWithdraw),
                0
            );

            await farm.exitFarm(
                {
                    from: withdrawAccount
                }
            );

            await farm.makeDepositForUser(
                bob,
                defaultTokenAmount,
                0
            );

            await time.increase(
                1
            );

            await farm.exitFarm(
                {
                    from: bob
                }
            );
        });

        it("should not be able to exit if nothing to claim, perform withdraw instead", async () => {

            const withdrawAccount = alice;

            const possibleWithdraw = await farm.balanceOf(
                withdrawAccount
            );

            // @TODO: check if still earning

            await farm.exitFarm(
                {
                    from: withdrawAccount
                }
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

        it("should be able to recover stakeTokens from the contract", async () => {

            const transferAmount = ONE_TOKEN;

            await rewardTokenA.transfer(
                farm.address,
                transferAmount
            );

            await rewardTokenB.transfer(
                farm.address,
                transferAmount
            );

            await farm.recoverTokens(
                rewardTokenA.address,
                transferAmount
            );

            await farm.recoverTokens(
                rewardTokenB.address,
                transferAmount
            );

            const balanceAfterA = await rewardTokenA.balanceOf(
                farm.address
            );

            const balanceAfterB = await rewardTokenB.balanceOf(
                farm.address
            );

            assert.equal(
                balanceAfterA.toString(),
                "0"
            );

            assert.equal(
                balanceAfterB.toString(),
                "0"
            );
        });

        it("should be able to recover rewardTokens from the contract", async () => {

            const transferAmount = ONE_TOKEN;

            await stakeToken.transfer(
                farm.address,
                transferAmount
            );

            await farm.recoverTokens(
                stakeToken.address,
                transferAmount
            );

            const balanceAfter = await stakeToken.balanceOf(
                farm.address
            );

            assert.equal(
                balanceAfter.toString(),
                "0"
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

            await stakeToken.approve(
                farm.address,
                defaultTokenAmount
            );

            await rewardTokenA.approve(
                farm.address,
                defaultTokenAmount
            );

            await rewardTokenB.approve(
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
                0
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                0
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

        it("should issue tokens accordingly to staked balances even if transferred 2", async () => {

            const aliceDeposit = tokens("100");
            const bobDeposit = tokens("9900");

            const SECONDS_IN_DAY = 86400;
            const THREE_MONTHS = 90 * SECONDS_IN_DAY;

            await farm.makeDepositForUser(
                alice,
                aliceDeposit,
                0
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

            const earnedByBobBeforeDeposit = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedByBobBeforeDeposit.toString(),
                "0"
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                0
            );

            const earnedByBobAfterDeposit = await farm.earnedA(
                bob
            );

            assert.equal(
                earnedByBobAfterDeposit.toString(),
                "0"
            );

            const depositedByBob = await farm.balanceOf(
                bob
            );

            const earnedByBobBeforeTransfer = await farm.earnedA(
                bob
            );

            await farm.transfer(
                alice,
                depositedByBob,
                {
                    from: bob
                }
            );

            const bobsBalance = await farm.balanceOf(bob);

            const earnedByBobAfterTransfer = await farm.earnedA(
                bob
            );

            // console.log(earnedByBobBeforeTransfer.toString(), 'earnedByBobBeforeTransfer');
            // console.log(earnedByBobAfterTransfer.toString(), 'earnedByBobAfterTransfer');
            // console.log(bobsBalance.toString(), 'bobsBalance');

            await expectRevert(
                farm.claimReward(
                    {
                        from: bob
                    }
                ),
                "TimeLockFarmV2Dual: NOTHING_TO_CLAIM"
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

        // @TODO: make same for token B
        it("should continue earning with higher/lower capacity after transfer", async () => {

            const aliceDeposit = tokens("5000");
            const bobDeposit = tokens("5000");

            // const SECONDS_IN_DAY = 86400;
            const TIME_STEP = 100;

            await farm.makeDepositForUser(
                alice,
                aliceDeposit,
                0
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                0
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

            assert.equal(
                parseInt(depositedByBob),
                parseInt(depositedByAlice)
            );

            await time.increase(
                TIME_STEP
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

            await farm.makeDepositForUser(
                alice,
                aliceDeposit,
                0
            );

            await farm.makeDepositForUser(
                bob,
                bobDeposit,
                0
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
