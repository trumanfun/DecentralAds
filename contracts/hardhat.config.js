require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

const { 
  PRIVATE_KEY, 
  FUJI_API_URL,
  FUJI_API_KEY, 
} = process.env;

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    artifacts: "./src/artifacts",
  },
  networks: {

  },
  etherscan: {
    apiKey: {
        snowtrace: FUJI_API_KEY,
    },

  }
};