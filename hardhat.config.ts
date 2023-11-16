import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

// when changing optimizer settings, make sure to also change settings in foundry.toml
const solidityProfiles = {
  default: {
    version: "0.8.16",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20000
      },
    }
  }
}

const config: HardhatUserConfig = {
  solidity: solidityProfiles.default,
  paths: {
    sources: "./src",
    cache: "./cache_hardhat",
  },
};

export default config;
