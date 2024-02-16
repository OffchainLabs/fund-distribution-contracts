import { expect } from 'chai'
import { testSetup } from '../../lib/arbitrum-sdk/scripts/testSetup'

type Unwrap<T> = T extends Promise<infer U> ? U : T

describe('E2E Sample', () => {
  // network information
  let setup: Unwrap<ReturnType<typeof testSetup>>

  before(async () => {
    setup = await testSetup()
  })

  it("sample test", async () => {
    expect((await setup.l1Deployer.getBalance()).lt(0))
  })
})
