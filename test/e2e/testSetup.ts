import * as dotenv from 'dotenv'
dotenv.config()
import { ArbitrumNetwork } from '@arbitrum/sdk'
import {
  DoubleProvider,
  DoubleWallet,
  getEnv,
} from '../../scripts/template/util'
import { execSync } from 'child_process'

export const isTestingOrbit = process.env.ORBIT_TEST === '1'

type BaseTestSetup = {
  l2Network: ArbitrumNetwork
  l1Signer: DoubleWallet
  l2Signer: DoubleWallet
  l1Provider: DoubleProvider
  l2Provider: DoubleProvider
}

export type OrbitTestSetup = BaseTestSetup & {
  isTestingOrbit: true
  l3Network: ArbitrumNetwork
  l3Provider: DoubleProvider
  l3Signer: DoubleWallet
}

export type NonOrbitTestSetup = BaseTestSetup & {
  isTestingOrbit: false
}

export type TestSetup = OrbitTestSetup | NonOrbitTestSetup

export async function testSetup(): Promise<TestSetup> {
  const l1Provider = new DoubleProvider(getEnv('LOCAL_L1_URL'))
  const l2Provider = new DoubleProvider(getEnv('LOCAL_L2_URL'))
  const l1Signer = new DoubleWallet(getEnv('LOCAL_L1_KEY'), l1Provider)
  const l2Signer = new DoubleWallet(getEnv('LOCAL_L2_KEY'), l2Provider)

  const l2Network = getArbitrumNetwork('l2')

  if (isTestingOrbit) {
    const l3Provider = new DoubleProvider(getEnv('LOCAL_L3_URL'))
    const l3Signer = new DoubleWallet(getEnv('LOCAL_L3_KEY'), l3Provider)

    const l3Network = getArbitrumNetwork('l3')

    return {
      l2Network,
      l3Network,
      l1Signer,
      l2Signer,
      l3Signer,
      l1Provider,
      l2Provider,
      l3Provider,
      isTestingOrbit,
    }
  } else {
    return {
      l2Network,
      l1Signer,
      l2Signer,
      l1Provider,
      l2Provider,
      isTestingOrbit,
    }
  }
}

// slightly modified from: https://github.com/OffchainLabs/arbitrum-sdk/blob/93f81c7c69aa3426db02fa078f585d6fd6ef4491/packages/sdk/scripts/genNetwork.ts#L17-L36
function getArbitrumNetwork(which: 'l2' | 'l3'): ArbitrumNetwork {
  const dockerNames = [
    'nitro_sequencer_1',
    'nitro-sequencer-1',
    'nitro-testnode-sequencer-1',
    'nitro-testnode_sequencer_1',
  ]
  for (const dockerName of dockerNames) {
    try {
      return JSON.parse(
        execSync(
          `docker exec ${dockerName} cat /tokenbridge-data/${which === 'l2' ? 'l1l2' : 'l2l3'}_network.json`,
          { stdio: ['ignore', 'pipe', 'ignore'] }
        ).toString()
      ).l2Network
    } catch {
      // empty on purpose
    }
  }
  throw new Error('nitro-testnode sequencer not found')
}
