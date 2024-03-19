import {  Wallet } from 'ethers'
import { JsonRpcProvider } from '@ethersproject/providers'

import { testSetup as sdkTestSetup } from '../../lib/arbitrum-sdk/scripts/testSetup'
import { L2Network, getL1Network } from '../../lib/arbitrum-sdk/src'
import { Unwrap, getEnv } from '../util/util'

export type TestSetup = Unwrap<ReturnType<typeof testSetup>>

export async function testSetup() {
  const l1Provider = new JsonRpcProvider(getEnv('LOCAL_L1_URL'))
  const l2Provider = new JsonRpcProvider(getEnv('LOCAL_L2_URL'))
  const l3Provider = new JsonRpcProvider(getEnv('LOCAL_L3_URL'))

  const l1Signer = new Wallet(getEnv('LOCAL_L1_KEY'), l1Provider)
  const l2Signer = new Wallet(getEnv('LOCAL_L2_KEY'), l2Provider)
  const l3Signer = new Wallet(getEnv('LOCAL_L3_KEY'), l3Provider)

  const setup = await sdkTestSetup()

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
  }
}
