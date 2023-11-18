import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "dotenv/config";
import "hardhat-contract-sizer";

export default {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
    ],
  },
  networks: {
    chiliz: {
      allowUnlimitedContractSize: true,
      url: "https://spicy-rpc.chiliz.com/",
      chainId: 88882,
      accounts: [process.env.TESTNET_KEY],
      gas: "auto",
      gasPrice: "auto",
      runs: 0,
    },
  },
  mocha: {
    timeout: 400000000,
  },
};
