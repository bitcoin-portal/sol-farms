const Token = artifacts.require("TestToken");
const Farm = artifacts.require("SimpleFarm");
const { expectRevert, time } = require('@openzeppelin/test-helpers');

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

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest",
    });
    return events.pop().returnValues;
};

contract("SimpleFarm", ([owner, alice, bob, chad, random]) => {

    const setupScenario = async (approval) => {

        stakeToken = await Token.new();
        rewardToken = await Token.new();

        defaultDurationInSeconds = 300;

        farm = await Farm.new(
            stakeToken.address,
            rewardToken.address,
            defaultDurationInSeconds
        );

        if (approval) {

            const approvalAmount = tokens(
                "100"
            );

            await stakeToken.approve(
                farm.address,
                approvalAmount
            );

            await rewardToken.approve(
                farm.address,
                approvalAmount
            );
        }

        return {
            stakeToken,
            rewardToken,
            farm
        }
    }

    describe.only("Farm initial values", () => {

        beforeEach(async () => {
            const result = await setupScenario();
            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
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

            const rewardTokenValue = await farm.rewardToken();

            assert.equal(
                rewardTokenValue,
                rewardToken.address
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
                    rewardToken.address,
                    invalidDuration
                ),
                "SimpleFarm: INVALID_DURATION"
            );

            await Farm.new(
                stakeToken.address,
                rewardToken.address,
                correctDuration
            );

            assert.isAbove(
                correctDuration,
                invalidDuration
            );
        });
    });

    describe.only("Duration initial functionality", () => {

        beforeEach(async () => {
            const result = await setupScenario();
            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
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
                "SimpleFarm: INVALID_MANAGER"
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

        it("should not be able to change farm duration value to 0 ", async () => {

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
                "SimpleFarm: INVALID_DURATION"
            );

            await farm.setRewardDuration(
                newDurationRightValue
            );

            assert.isAbove(
                newDurationRightValue,
                newDurationWrongValue
            );
        });
    });

    describe.only("Reward allocation initial functionality by manager", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;
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

            await farm.farmDeposit(
                ONE_TOKEN
            );

            await farm.setRewardRate(
                initialRate
            );

            const initialTimestamp = await rewardToken.timestamp();
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

        it("manager should be able to set rewards rate only if stakers exist", async () => {

            const newRewardRate = 10;
            const expectedNewRate = newRewardRate;

            await expectRevert(
                farm.setRewardRate(
                    newRewardRate
                ),
                "SimpleFarm: NO_STAKERS"
            );

            await farm.farmDeposit(
                ONE_TOKEN
            );

            await farm.setRewardRate(
                newRewardRate
            );

            const rateAfterChanged = await farm.rewardRate();

            assert.equal(
                rateAfterChanged,
                expectedNewRate
            );
        });

        it("manager should fund the farm during reward rate announcement", async () => {

            const newRewardRate = 10;
            const expectedDuration = await farm.rewardDuration();
            const currentManager = await farm.managerAddress();

            const expectedTransferAmount = newRewardRate
                * expectedDuration;

            const managerBalance = await rewardToken.balanceOf(
                currentManager
            );

            assert.isAbove(
                parseInt(managerBalance),
                expectedTransferAmount
            );

            await farm.farmDeposit(
                ONE_TOKEN
            );

            await farm.setRewardRate(
                newRewardRate
            );

            const transferData = await getLastEvent(
                "Transfer",
                rewardToken
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

            const afterTransferManager = await rewardToken.balanceOf(
                currentManager
            );

            const afterTransferFarm = await rewardToken.balanceOf(
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

            await farm.farmDeposit(
                ONE_TOKEN
            );

            await farm.setRewardRate(
                initialRate
            );

            const rateBeforeChanged = await farm.rewardRate();

            assert.equal(
                rateBeforeChanged,
                initialRate
            );

            await farm.setRewardRate(
                increasedRewardRate
            );

            const rateAfterChanged = await farm.rewardRate();

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

            await farm.farmDeposit(
                ONE_TOKEN
            );

            await farm.setRewardRate(
                initialRate
            );

            const rateAfterChanged = await farm.rewardRate();

            assert.equal(
                rateAfterChanged,
                initialRate
            );

            await expectRevert(
                farm.setRewardRate(
                    decreasedRewardRate
                ),
                "SimpleFarm: RATE_CANT_DECREASE"
            );

            const currentDuration = await farm.rewardDuration();

            await time.increase(
                currentDuration
            );

            await farm.setRewardRate(
                decreasedRewardRate
            );

            const newRate = await farm.rewardRate();

            assert.equal(
                parseInt(newRate),
                decreasedRewardRate
            );
        });
    });

    describe.only("Deposit initial functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
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

            await farm.farmDeposit(
                depositValue,
                {
                    from: depositAddress
                }
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

            await farm.farmDeposit(
                depositAmount,
                {
                    from: owner
                }
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

            await farm.farmDeposit(
                depositAmount,
                {
                    from: owner
                }
            );

            const totalSupply = await farm.totalSupply();

            assert.equal(
                totalSupply.toString(),
                (BN(supplyBefore).add(BN(depositAmount))).toString()
            );
        });
    });

    describe.only("Receipt Token Transfer Functionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;

            defaultTokenAmount = TWO_TOKENS;

            await farm.farmDeposit(
                defaultTokenAmount
            );
        });

        it("should transfer correct amount from walletA to walletB", async () => {

            const transferValue = defaultTokenAmount;
            const balanceBefore = await farm.balanceOf(bob);

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

        it("should reduce wallets balance after transfer", async () => {

            const transferValue = defaultTokenAmount;
            const balanceBefore = await farm.balanceOf(owner);

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

        it("should emit correct Transfer event", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecepient = bob;

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

        it("should update the balance of the recipient when using transferFrom", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecipient = bob;
            const balanceBefore = await farm.balanceOf(bob);

            await farm.approve(
                owner,
                transferValue
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

        it("should deduct from the balance of the sender when using transferFrom", async () => {

            const transferValue = defaultTokenAmount;
            const expectedRecipient = bob;
            const balanceBefore = await farm.balanceOf(owner);

            await farm.approve(
                owner,
                transferValue
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

    describe.only("Witharaw initial dunctionality", () => {

        beforeEach(async () => {

            const result = await setupScenario({
                approval: true
            });

            stakeToken = result.stakeToken;
            rewardToken = result.rewardToken;
            farm = result.farm;

            defaultTokenAmount = TWO_TOKENS;

            await farm.farmDeposit(
                defaultTokenAmount
            );
        });

        it("should reduce the balance of the wallet thats withrawing the stakeTokens", async () => {

            const withdrawAmount = ONE_TOKEN;
            const withdrawAccount = owner;

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
            const withdrawAccount = owner;

            const supplyBefore = await farm.balanceOf(
                withdrawAccount
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
    });

    describe.only("Master Functionality", () => {

        it("should have correct master address", async () => {

            const expectedAddress = owner;
            const ownerAddress = await farm.ownerAddress();

            assert.equal(
                expectedAddress,
                ownerAddress
            );
        });

        it("should have correct master address based on from wallet", async () => {

            const expectedAddress = alice;

            const newFarm = await Farm.new(
                stakeToken.address,
                rewardToken.address,
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

        it("should be able to announce new master only by current master", async () => {

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
                "SimpleFarm: INVALID_OWNER"
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

        it("should be able to claim master only by proposed wallet", async () => {

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
                "SimpleFarm: INVALID_OWNER"
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
                "SimpleFarm: INVALID_CANDIDATE"
            );

            await expectRevert(
                farm.claimOwnership(
                    {
                        from: wrongOwner
                    }
                ),
                "SimpleFarm: INVALID_CANDIDATE"
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
    });

    describe("Manager Functionality", () => {

            it("should have correct master address", async () => {

                const expectedAddress = owner;
                const ownerAddress = await farm.ownerAddress();

                assert.equal(
                    expectedAddress,
                    ownerAddress
                );
            });

            it("should have correct master address based on from wallet", async () => {

                const expectedAddress = alice;

                const newFarm = await Farm.new(
                    stakeToken.address,
                    rewardToken.address,
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

            it("should be able to announce new master only by current master", async () => {

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
                    "SimpleFarm: INVALID_OWNER"
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

            it("should be able to claim master only by proposed wallet", async () => {

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
                    "SimpleFarm: INVALID_OWNER"
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
                    "SimpleFarm: INVALID_CANDIDATE"
                );

                await expectRevert(
                    farm.claimOwnership(
                        {
                            from: wrongOwner
                        }
                    ),
                    "SimpleFarm: INVALID_CANDIDATE"
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

            await farm.farmDeposit(
                defaultTokenAmount
            );

            await farm.setRewardRate(

            );
        });

        it("should reduce the balance of the wallet thats withdrawing the tokens", async () => {

            const burnAmount = ONE_TOKEN;
            const supplyBefore = await token.balanceOf(owner);

            await token.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const supplyAfter = await token.balanceOf(owner);

            assert.equal(
                supplyAfter,
                supplyBefore - burnAmount
            );
        });

        it("should deduct the correct amount from the total supply", async () => {

            const supplyBefore = await token.balanceOf(owner);
            const burnAmount = ONE_TOKEN;

            await token.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const totalSupply = await token.totalSupply();

            assert.equal(
                totalSupply,
                supplyBefore - burnAmount
            );
        });
    });

    describe("Claim functionality", () => {

        it("should reduce the balance of the wallet thats burnng the tokens", async () => {

            const burnAmount = ONE_TOKEN;
            const supplyBefore = await token.balanceOf(owner);

            await token.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const supplyAfter = await token.balanceOf(owner);

            assert.equal(
                supplyAfter,
                supplyBefore - burnAmount
            );
        });

        it("should deduct the correct amount from the total supply", async () => {

            const supplyBefore = await token.balanceOf(owner);
            const burnAmount = ONE_TOKEN;

            await token.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const totalSupply = await token.totalSupply();

            assert.equal(
                totalSupply,
                supplyBefore - burnAmount
            );
        });
    });

    describe("Exit functionality", () => {

        it("should reduce the balance of the wallet thats burnng the tokens", async () => {

            const burnAmount = ONE_TOKEN;
            const supplyBefore = await token.balanceOf(owner);

            await token.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const supplyAfter = await token.balanceOf(owner);

            assert.equal(
                supplyAfter,
                supplyBefore - burnAmount
            );
        });

        it("should deduct the correct amount from the total supply", async () => {

            const supplyBefore = await token.balanceOf(owner);
            const burnAmount = ONE_TOKEN;

            await token.burn(
                burnAmount,
                {
                    from: owner
                }

            );

            const totalSupply = await token.totalSupply();

            assert.equal(
                totalSupply,
                supplyBefore - burnAmount
            );
        });
    });
});
