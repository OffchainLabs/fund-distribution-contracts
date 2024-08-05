import { testSetup as sdkTestSetup } from '../../lib/arbitrum-sdk/scripts/testSetup'
import { L1Network, L2Network, getL1Network } from '../../lib/arbitrum-sdk/src'
import {
  DoubleProvider,
  DoubleWallet,
  getEnv,
} from '../../scripts/template/util'

export const isTestingOrbit = process.env.ORBIT_TEST === '1'

type BaseTestSetup = {
  l1Network: L1Network
  l2Network: L2Network
  l1Signer: DoubleWallet
  l2Signer: DoubleWallet
  l1Provider: DoubleProvider
  l2Provider: DoubleProvider
}

export type OrbitTestSetup = BaseTestSetup & {
  isTestingOrbit: true
  l3Network: L2Network
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

  const setup = await sdkTestSetup()

  if (isTestingOrbit) {
    const l3Provider = new DoubleProvider(getEnv('LOCAL_L3_URL'))
    const l3Signer = new DoubleWallet(getEnv('LOCAL_L3_KEY'), l3Provider)

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
    }
  }
}
