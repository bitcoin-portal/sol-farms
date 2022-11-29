const Web3 = require('web3');
const HDWalletProvider = require("@truffle/hdwallet-provider");

const privateKeys = [
    "",
];

const provider =  new HDWalletProvider(
    privateKeys,
    "https://goerli.infura.io/v3/", // get from infura.io
    0, // start at address_index 0 and load both addresses
    1  // start at address_index 0 and load both addresses
);

const web3 = new Web3(
    provider
);

const CONTRACT_CODE = require('../build/contracts/SmartContract.json').bytecode
const CONTRACT_ABI = require('../build/contracts/SmartContract.json').abi

const deploy = async () => {

    try {

        const accounts = await web3.eth.getAccounts();
        const contract = new web3.eth.Contract(
            CONTRACT_ABI
        );

        console.log(
            `deploying from: ${accounts[0]}`
        );

        const instance = await contract.deploy({
            arguments: [
                // parameterA,
                // parameterB,
            ],
            data: CONTRACT_CODE
        }).send({
            from: accounts[0]
        });

        console.log(
            `deployed at ${instance._address}`
        );

        /* call contract example
        const result = await instance.methods.updateRouter(
            parameterA,
            parameterB
        ).send({
            from: accounts[0]
        });
        */

        process.exit();

    } catch (e) {
        console.log(e);
        process.exit(1);
    }
};

deploy();
