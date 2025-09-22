import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-foundry'
import 'hardhat-contract-sizer'

import { SolcUserConfig } from 'hardhat/types'
import toml from 'toml'
import fs from 'fs'

const config: HardhatUserConfig = {
  solidity: {
    ...getSolidityConfigFromFoundryToml(process.env.FOUNDRY_PROFILE),
    // overrides here
    // overrides: {
    //   'contracts/MyContract.sol': {
    //     version: '0.8.0',
    //     settings: {
    //       optimizer: {
    //         enabled: false,
    //       },
    //     },
    //   },
    // },
  },
  networks: {
    fork: {
      url: process.env.FORK_URL || 'http://localhost:8545',
    },
  },
}

function getSolidityConfigFromFoundryToml(
  profile: string | undefined
): SolcUserConfig {
  const data = toml.parse(fs.readFileSync('foundry.toml', 'utf-8'))

  const defaultConfig = data.profile['default']
  const profileConfig = data.profile[profile || 'default']

  const solidity = {
    version: profileConfig?.solc_version || defaultConfig.solc_version,
    settings: {
      optimizer: {
        enabled: true,
        runs: profileConfig?.optimizer_runs || defaultConfig.optimizer_runs,
      },
    },
  }

  return solidity
}

export default config
