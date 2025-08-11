import { expect } from 'chai'
import { Counter__factory } from '../../typechain-types'
import { TestSetup, testSetup } from './testSetup'

/*
This repository uses ethers v6, but the arbitrum sdk uses ethers v5. 

Using the sdk might be a bit tricky, but you can import v5 like this:
import { ethers as ethersv5 } from 'ethers-v5'

testSetup will return both v5 and v6 versions of signers and providers.
*/

describe('E2E Sample', () => {
  let setup: TestSetup

  before(async function () {
    setup = await testSetup()
  })

  it('should have the correct network information', async function () {
    expect((await setup.l1Provider.getNetwork()).chainId).to.eq(1337n)
    expect((await setup.l2Provider.getNetwork()).chainId)
      .to.eq(BigInt(setup.l2Network.chainId))
      .to.eq(412346n)
    if (setup.isTestingOrbit)
      expect((await setup.l3Provider.getNetwork()).chainId)
        .to.eq(BigInt(setup.l3Network.chainId))
        .to.eq(333333n)
  })

  describe('Deployment', () => {
    it('should deploy Counter to L1', async function () {
      const counter = await new Counter__factory(setup.l1Signer).deploy()
      await counter.deploymentTransaction()!.wait()
      expect(await counter.number()).to.eq(0n)
    })

    it('should deploy Counter to L2', async function () {
      const counter = await new Counter__factory(setup.l2Signer).deploy()
      await counter.deploymentTransaction()!.wait()
      expect(await counter.number()).to.eq(0n)
    })

    it('should deploy Counter to L3', async function () {
      if (!setup.isTestingOrbit) this.skip()

      const counter = await new Counter__factory(setup.l3Signer).deploy()
      await counter.deploymentTransaction()!.wait()
      expect(await counter.number()).to.eq(0n)
    })
  })
})
