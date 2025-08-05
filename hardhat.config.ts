import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from 'dotenv'
dotenv.config()

const config: HardhatUserConfig = {
  defaultNetwork: "bscTestnet",
  solidity: {
    compilers: [
      {
        version: '0.8.20',
        settings: {
          optimizer: {
            enabled: true,
            runs: 50,
          },
        },
      },
    ],
  },
  sourcify: {
    enabled: true
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
      chainId: 1,
    },
    bscTestnet: {
      url: process.env.EVM_RPC!,
      chainId: 97,
      accounts: [
        process.env.PRIVATE!,
      ]
    },
  },
  etherscan: {
    apiKey: process.env.API_KEY!,
  }
};
export default config;
