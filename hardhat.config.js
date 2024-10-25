/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-truffle5");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-ethers");
require("solidity-coverage");
require("@nomicfoundation/hardhat-foundry");

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
                url: "https://eth-mainnet.g.alchemy.com/v2/J3bTM7KLiYYwh8Ar_VBXuo-oLlGTx7od",
                //url: "https://rpc.ankr.com/eth",
                blockNumber: 18704404,
                enabled: true
            }
        },
    },
    solidity: {
        version: "0.8.26",
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
