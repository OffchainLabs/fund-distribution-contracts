import { JsonRpcProvider, Wallet } from 'ethers'
import { ethers as ethersv5 } from 'ethers-v5'
import { testSetup as sdkTestSetup } from '../../lib/arbitrum-sdk/scripts/testSetup'
import { L1Network, L2Network, getL1Network } from '../../lib/arbitrum-sdk/src'
import { getEnv } from '../util/util'

export const isTestingOrbit = process.env.ORBIT_TEST === '1'

type BaseTestSetup = {
  l1Network: L1Network
  l2Network: L2Network
  l1Signer: Wallet
  l2Signer: Wallet
  l1Provider: JsonRpcProvider
  l2Provider: JsonRpcProvider
  v5: {
    l1Signer: ethersv5.Wallet
    l1Provider: ethersv5.providers.JsonRpcProvider
    l2Signer: ethersv5.Wallet
    l2Provider: ethersv5.providers.JsonRpcProvider
  }
}

export type OrbitTestSetup = BaseTestSetup & {
  isTestingOrbit: true
  l3Network: L2Network
  l3Provider: JsonRpcProvider
  l3Signer: Wallet
  v5: {
    l3Signer: ethersv5.Wallet
    l3Provider: ethersv5.providers.JsonRpcProvider
  }
}

export type NonOrbitTestSetup = BaseTestSetup & {
  isTestingOrbit: false
}

export type TestSetup = OrbitTestSetup | NonOrbitTestSetup

export async function testSetup(): Promise<TestSetup> {
  const l1Provider = new JsonRpcProvider(getEnv('LOCAL_L1_URL'))
  const l2Provider = new JsonRpcProvider(getEnv('LOCAL_L2_URL'))
  const l1Signer = new Wallet(getEnv('LOCAL_L1_KEY'), l1Provider)
  const l2Signer = new Wallet(getEnv('LOCAL_L2_KEY'), l2Provider)

  const v5L1Provider = new ethersv5.providers.JsonRpcProvider(
    getEnv('LOCAL_L1_URL')
  )
  const v5L2Provider = new ethersv5.providers.JsonRpcProvider(
    getEnv('LOCAL_L2_URL')
  )
  const v5L1Signer = new ethersv5.Wallet(getEnv('LOCAL_L1_KEY'), v5L1Provider)
  const v5L2Signer = new ethersv5.Wallet(getEnv('LOCAL_L2_KEY'), v5L2Provider)

  const setup = await sdkTestSetup()

  if (isTestingOrbit) {
    const l3Provider = new JsonRpcProvider(getEnv('LOCAL_L3_URL'))
    const l3Signer = new Wallet(getEnv('LOCAL_L3_KEY'), l3Provider)

    const v5L3Provider = new ethersv5.providers.JsonRpcProvider(
      getEnv('LOCAL_L3_URL')
    )
    const v5L3Signer = new ethersv5.Wallet(getEnv('LOCAL_L3_KEY'), v5L3Provider)

    const l1Network = await getL1Network(
      (setup.l1Network as L2Network).partnerChainID
    )
    const l2Network = setup.l1Network as L2Network
    const l3Network = setup.l2Network

    return {
      l1Network,
      l2Network,
      l3Network,
      l1Signer,
      l2Signer,
      l3Signer,
      l1Provider,
      l2Provider,
      l3Provider,
      isTestingOrbit,
      v5: {
        l1Signer: v5L1Signer,
        l2Signer: v5L2Signer,
        l3Signer: v5L3Signer,
        l1Provider: v5L1Provider,
        l2Provider: v5L2Provider,
        l3Provider: v5L3Provider,
      },
    }
  } else {
    const l1Network = setup.l1Network as L1Network
    const l2Network = setup.l2Network

    return {
      l1Network,
      l2Network,
      l1Signer,
      l2Signer,
      l1Provider,
      l2Provider,
      isTestingOrbit,
      v5: {
        l1Signer: v5L1Signer,
        l2Signer: v5L2Signer,
        l1Provider: v5L1Provider,
        l2Provider: v5L2Provider,
      },
    }
  }
}
