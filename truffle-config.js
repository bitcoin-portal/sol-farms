const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
    plugins: [
        "solidity-coverage",
        "truffle-plugin-verify"
    ],
    networks: {
        development: {
            host: "127.0.0.1",
            port: 9545,
            gasLimit: 8000000,
            network_id: 5777
        },
    },
    mocha: {
        useColors: true,
        reporter: "eth-gas-reporter",
        reporterOptions: {
            currency: "USD",
            gasPrice: 5
        }
    },
    compilers: {
        solc: {
            version: "^0.8.17",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                },
            }
        }
    }
};
