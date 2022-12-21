const Token = artifacts.require("TestToken");
const Farm = artifacts.require("SimpleFarm");
const catchRevert = require("./exceptionsHelpers.js").catchRevert;

require("./utils");

const _BN = web3.utils.BN;
const BN = (value) => {
    return new _BN(value)
}

const tokens = (value) => {
    return web3.utils.toWei(value);
}

const getLastEvent = async (eventName, instance) => {
    const events = await instance.getPastEvents(eventName, {
        fromBlock: 0,
        toBlock: "latest",
    });
    return events.pop().returnValues;
};


contract("SimpleFarm", ([owner, alice, bob, random]) => {

    describe.only("Farm Initial Values", () => {

        beforeEach(async () => {
            token = await Token.new();

            stakeToken = await Token.new();
            rewardToken = await Token.new();

            farm = await Farm.new(
                stakeToken.address,
                rewardToken.address
            );
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
            const supply = await farm.totalSupply();
            assert.equal(
                supply,
                0
            );
        });

        it("should return receipt balance for the given account", async () => {

            const balance = await farm.balanceOf(
                owner
            );

            assert.equal(
                balance,
                0
            );
        });

        it("should return the correct allowance for the given spender", async () => {

            const allowance = await farm.allowance(
                owner,
                bob
            );

            assert.equal(
                allowance,
                0
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
    });

    describe("Receipt Token Transfer Functionality", () => {

        it("should transfer correct amount from walletA to walletB", async () => {

            const transferValue = ONE_TOKEN;
            const balanceBefore = await token.balanceOf(bob);

            await token.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await token.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should revert if not enough balance in the wallet", async () => {

            const balanceBefore = await token.balanceOf(alice);

            await catchRevert(
                token.transfer(
                    bob,
                    parseInt(balanceBefore) + 1,
                    {
                        from: alice
                    }
                )
            );
        });

        it("should reduce wallets balance after transfer", async () => {

            const transferValue = ONE_TOKEN;
            const balanceBefore = await token.balanceOf(owner);

            await token.transfer(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const balanceAfter = await token.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should emit correct Transfer event", async () => {

            const transferValue = ONE_TOKEN;
            const expectedRecepient = bob;

            await token.transfer(
                expectedRecepient,
                transferValue,
                {
                    from: owner
                }
            );

            const { from, to, value } = await getLastEvent(
                "Transfer",
                token
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
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;
            const balanceBefore = await token.balanceOf(bob);

            await token.approve(
                owner,
                transferValue
            );

            await token.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await token.balanceOf(bob);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) + parseInt(transferValue)
            );
        });

        it("should deduct from the balance of the sender when using transferFrom", async () => {
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;
            const balanceBefore = await token.balanceOf(owner);

            await token.approve(
                owner,
                transferValue
            );

            await token.transferFrom(
                owner,
                expectedRecipient,
                transferValue,
            );

            const balanceAfter = await token.balanceOf(owner);

            assert.equal(
                parseInt(balanceAfter),
                parseInt(balanceBefore) - parseInt(transferValue)
            );
        });

        it("should revert if there is no approval when using transferFrom", async () => {
            const transferValue = ONE_TOKEN;
            const expectedRecipient = bob;

            await catchRevert(
                token.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue
                ),
                "revert REQUIRES APPROVAL"
            );
        });

        it("should revert if the sender has spent more than their approved amount when using transferFrom", async () => {

            const approvedValue = ONE_TOKEN;
            const transferValue = FOUR_ETH;
            const expectedRecipient = bob;

            await token.approve(
                alice,
                approvedValue
            );

            await catchRevert(
                token.transferFrom(
                    owner,
                    expectedRecipient,
                    transferValue,
                    {
                        from: alice
                    }
                ),
                "revert AMOUNT EXCEEDS APPROVED VALUE"
            );
        });
    });

    describe("Receipt Token Approval Functionality", () => {

        it("should assign value to allowance mapping", async () => {

            const approvalValue = ONE_TOKEN;

            await token.approve(
                bob,
                approvalValue,
                {
                    from: owner
                }
            );

            const allowanceValue = await token.allowance(
                owner,
                bob
            );

            assert.equal(
                approvalValue,
                allowanceValue
            );
        });

        it("should emit a correct Approval event", async () => {

            const transferValue = ONE_TOKEN;

            await token.approve(
                bob,
                transferValue,
                {
                    from: owner
                }
            );

            const { owner: transferOwner, spender, value } = await getLastEvent(
                "Approval",
                token
            );

            assert.equal(
                transferOwner,
                owner
            );

            assert.equal(
                spender,
                bob
            );

            assert.equal(
                value,
                transferValue
            );
        });
    });

    describe("Master Functionality", () => {

        it("should have correct master address", async () => {

            const expectedAddress = owner;
            const masterAddress = await token.master();

            assert.equal(
                expectedAddress,
                masterAddress
            );
        });

        it("should have correct master address based on from wallet", async () => {

            newToken = await Token.new(
                {from: alice}
            );

            const expectedAddress = alice;
            const masterAddress = await newToken.master();

            assert.equal(
                expectedAddress,
                masterAddress
            );
        });
    });

    describe("Deposit Functionality", () => {

        it("should increase the balance of the wallet thats deposits the tokens", async () => {

            const depositAmount = tokens("1");

            const supplyBefore = await token.balanceOf(
                owner
            );

            await farm.farmDeposit(
                depositAmount,
                {
                    from: owner
                }
            );

            const supplyAfter = await token.balanceOf(
                owner
            );

            assert.equal(
                parseInt(supplyAfter),
                parseInt(supplyBefore) + parseInt(depositAmount)
            );
        });

        it("should add the correct amount to the total supply", async () => {

            const supplyBefore = await token.balanceOf(owner);
            const mintAmount = ONE_TOKEN;

            await token.mint(
                mintAmount,
                {
                    from: owner
                }
            );

            const totalSupply = await token.totalSupply();

            assert.equal(
                BN(totalSupply).toString(),
                (BN(supplyBefore).add(BN(mintAmount))).toString()
            );
        });

        it("should increase the balance for the wallet decided by master", async () => {

            const mintAmount = ONE_TOKEN;
            const mintWallet = bob;

            const supplyBefore = await token.balanceOf(mintWallet);

            await token.mintByMaster(
                mintAmount,
                mintWallet,
                {
                    from: owner
                }
            );

            const supplyAfter = await token.balanceOf(mintWallet);

            assert.equal(
                parseInt(supplyAfter),
                parseInt(supplyBefore) + parseInt(mintAmount)
            );
        });

        it("should add the correct amount to the total supply (mintByMaster)", async () => {

            const mintWallet = bob;
            const mintAmount = ONE_TOKEN;

            const suppleBefore = await token.totalSupply();

            await token.mintByMaster(
                mintAmount,
                mintWallet,
                {
                    from: owner
                }
            );

            const supplyAfter = await token.totalSupply();

            assert.equal(
                parseInt(supplyAfter),
                parseInt(suppleBefore) + parseInt(mintAmount)
            );
        });

        it("should only allow to mint from master address", async () => {

            const mintWallet = bob;
            const mintAmount = ONE_TOKEN;

            await catchRevert(
                token.mintByMaster(
                    mintAmount,
                    mintWallet,
                    {
                        from: alice
                    }
                ),
                "revert Token: INVALID_MASTER"
            );
        });

    });

    describe("Witharaw Functionality", () => {

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
