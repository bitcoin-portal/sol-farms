/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-truffle5");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-ethers");
require("solidity-coverage");

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 1337,
            allowUnlimitedContractSize: false,
            blockGasLimit: 100000000,
            callGasLimit: 100000000,
            forking: {
                //url: "https://eth-goerli.g.alchemy.com/v2/LkGRjN6D4ckwZPVR0ykEClPrr9GJkbxu",
                url: "https://eth-mainnet.g.alchemy.com/v2/zPmVOUjzNasrehZtLBkXyYSqutQT2A5o",
                //url: "https://rpc.ankr.com/eth",
                blockNumber: 15940719,
                enabled: true
            }
        },
    },
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    mocha: {
        timeout: 4000000
    }
}
