import { assert } from 'chai'
import { testSetup } from '../../lib/arbitrum-sdk/scripts/testSetup'
import { Wallet, ethers } from 'ethers'
import { L1Network, L2Network, getL1Network } from '../../lib/arbitrum-sdk/src'

function getEnv(name: string): string {
  const value = process.env[name]
  if (!value) {
    throw new Error(`Missing env variable: ${name}`)
  }
  return value
}

const l1Signer = new Wallet(getEnv('LOCAL_L1_KEY'), new ethers.providers.JsonRpcProvider(getEnv('LOCAL_L1_URL')))
const l2Signer = new Wallet(getEnv('LOCAL_L2_KEY'), new ethers.providers.JsonRpcProvider(getEnv('LOCAL_L2_URL')))
const l3Signer = new Wallet(getEnv('LOCAL_L3_KEY'), new ethers.providers.JsonRpcProvider(getEnv('LOCAL_L3_URL')))

describe('E2E Sample', () => {
  let l1Network: L1Network
  let l2Network: L2Network
  let l3Network: L2Network

  before(async () => {
    // setup.l1Network is actually the L2 network
    const setup = await testSetup()

    l1Network = await getL1Network((setup.l1Network as L2Network).partnerChainID)
    l2Network = setup.l1Network as L2Network
    l3Network = setup.l2Network
  })

  it("sample test", async () => {
    assert((await l1Signer.getBalance()).gt(0))
    assert((await l2Signer.getBalance()).gt(0))
    assert((await l3Signer.getBalance()).gt(0))
  })
})
