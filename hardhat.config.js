require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("dotenv").config();
require("hardhat-contract-sizer");
require("hardhat-tracer");

const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const TESTNET_URL = process.env.TESTNET_RPC;
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      allowUnlimitedContractSize: true,
      forking: {
        url: MAINNET_RPC_URL,
      },
    },
    arbitrum_rinkeby: {
      chainId: 421611,
      url: TESTNET_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.7",
      },
      {
        version: "0.8.9",
      },
      { version: "0.8.10" },
      { version: "0.6.12" },
      { version: "0.8.14" },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  skipFiles: ["contracts/mocks/*.sol", "contracts/Bancor/*.sol"],
};
