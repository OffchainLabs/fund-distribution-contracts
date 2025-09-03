import { expect } from 'chai'
import { TestSetup, testSetup } from './testSetup'
import {
  ParentToChildRewardRouter__factory,
  ParentToChildRewardRouter,
  ChildToParentRewardRouter,
  RewardDistributor__factory,
  RewardDistributor,
  ArbChildToParentRewardRouter__factory,
} from '../../typechain-types'
import { ArbChildToParentMessageRedeemer } from '../../scripts/ts/FeeRouter/ChildToParentMessageRedeemer'
import { checkAndRouteFunds } from '../../scripts/ts/FeeRouter/checkAndRouteFunds'
import { Erc20Bridger } from '@arbitrum/sdk'
import { Contract, ContractFactory, parseEther, Wallet } from 'ethers'

import TestTokenAbi from '../../out/TestToken.sol/TestToken.json'
import { BigNumber } from 'ethers-v5'

describe('Router e2e test', () => {
  let setup: TestSetup
  let parentToChildRewardRouter: ParentToChildRewardRouter
  let childToParentRewardRouter: ChildToParentRewardRouter
  let rewardDistributor: RewardDistributor
  let testToken: Contract
  let l2TestToken: Contract
  const destination = Wallet.createRandom().address

  console.log('destination', destination)

  before(async () => {
    setup = await testSetup()
    console.log(
      'using L1 wallet:',
      setup.l1Signer.address,
      await setup.l1Signer.v5.getBalance()
    )
    console.log(
      'using L2 wallet:',
      setup.l2Signer.address,
      await setup.l2Signer.v5.getBalance()
    )

    testToken = (await new ContractFactory(
      TestTokenAbi.abi,
      TestTokenAbi.bytecode,
      setup.l1Signer
    ).deploy(100n ** 18n)) as Contract
    await testToken.deploymentTransaction()!.wait()

    console.log('Test token L1 deployed', await testToken.getAddress())

    // Initial token deposit:
    const erc20Bridger = new Erc20Bridger(setup.l2Network)

    await (
      await erc20Bridger.approveToken({
        erc20ParentAddress: await testToken.getAddress(),
        parentSigner: setup.l1Signer.v5,
      })
    ).wait()
    const depositRes = await erc20Bridger.deposit({
      amount: BigNumber.from(1000),
      erc20ParentAddress: await testToken.getAddress(),
      parentSigner: setup.l1Signer.v5,
      childProvider: setup.l2Provider.v5,
    })

    const depositRec = await depositRes.wait()

    console.log('waiting for retryables')

    await depositRec.waitForChildTransactionReceipt(setup.l2Signer.v5)
    const l2TokenAddress = await erc20Bridger.getChildErc20Address(
      await testToken.getAddress(),
      setup.l1Provider.v5
    )

    console.log('L2 test token:', l2TokenAddress)

    l2TestToken = new Contract(l2TokenAddress, TestTokenAbi.abi, setup.l2Signer)

    // deploy parent to child
    console.log('Deploying parentToChildRewardRouter:')

    parentToChildRewardRouter = await new ParentToChildRewardRouter__factory(
      setup.l1Signer
    ).deploy(
      setup.l2Network.tokenBridge!.parentGatewayRouter,
      destination,
      10,
      100000000,
      300000
    )
    console.log(
      'ParentToChildRewardRouter deployed',
      await parentToChildRewardRouter.getAddress()
    )

    console.log('Deploying childToParentRewardRouter:')

    // deploy child to parent
    childToParentRewardRouter = await new ArbChildToParentRewardRouter__factory(
      setup.l2Signer
    ).deploy(
      await parentToChildRewardRouter.getAddress(),
      10,
      await testToken.getAddress(),
      l2TokenAddress,
      setup.l2Network.tokenBridge!.childGatewayRouter
    )
    console.log(
      'childToParentRewardRouter deployed:',
      await childToParentRewardRouter.getAddress()
    )

    // deploy fund distributor
    console.log('Deploying rewardDistributor:')

    rewardDistributor = await new RewardDistributor__factory(
      setup.l2Signer
    ).deploy([childToParentRewardRouter.getAddress()], [10000])
    console.log(
      'Reward Distributor deployed:',
      await rewardDistributor.getAddress()
    )
  })

  it('should have the correct network information', async () => {
    expect(setup.l2Network.parentChainId).to.eq(1337)
    expect(setup.l2Network.chainId).to.eq(412346)
  })

  describe('e2e eth routing test', async () => {
    const ethValue = parseEther('.23')
    it('destination has initial balance of 0', async () => {
      const initialBal = await setup.l2Provider.getBalance(destination)
      expect(initialBal).to.eq(0n)
    })

    // fund reward distributor
    it('funds and pokes reward distributor', async () => {
      await (
        await setup.l2Signer.sendTransaction({
          value: ethValue,
          to: rewardDistributor.getAddress(),
        })
      ).wait()

      // poke reward distributor
      await (
        await rewardDistributor.distributeRewards(
          [childToParentRewardRouter.getAddress()],
          [10000]
        )
      ).wait()

      // fund should be distributed and auto-routed
      expect(
        await setup.l2Provider.getBalance(rewardDistributor.getAddress())
      ).to.equal(0n)

      expect(
        await setup.l2Provider.getBalance(
          childToParentRewardRouter.getAddress()
        )
      ).to.equal(0n)
    })

    it('redeems l2 to l1 message', async () => {
      await new ArbChildToParentMessageRedeemer(
        setup.l2Provider.v5.connection.url,
        setup.l1Provider.v5.connection.url,
        setup.l1Signer.privateKey,
        await childToParentRewardRouter.getAddress(),
        0,
        0,
        1000
      ).redeemChildToParentMessages()

      // funds should be in parentToChildRewardRouter now
      expect(
        await setup.l1Provider.getBalance(
          parentToChildRewardRouter.getAddress()
        )
      ).to.eq(ethValue)
    })

    it('routes runds to destination ', async () => {
      await checkAndRouteFunds(
        'ETH',
        setup.l1Signer,
        setup.l2Signer,
        await parentToChildRewardRouter.getAddress(),
        0n
      )
      expect(await setup.l2Provider.getBalance(destination)).to.eq(ethValue)
    })
  })

  describe('token routing test', async () => {
    const tokenValue = BigNumber.from(231)
    it('destination has initial balance of 0', async () => {
      const initialBal = await l2TestToken.balanceOf(destination)

      expect(initialBal.toNumber()).to.eq(0)
    })

    it('funds and pokes child to parent router', async () => {
      await l2TestToken.transfer(
        childToParentRewardRouter.getAddress(),
        tokenValue
      )

      // prePokeBlock = setup.l2
      await (await childToParentRewardRouter.routeToken()).wait()
      expect(
        (
          await l2TestToken.balanceOf(childToParentRewardRouter.getAddress())
        ).toNumber()
      ).to.eq(0)
    })

    it('redeems l2 to l1 message', async () => {
      await new ArbChildToParentMessageRedeemer(
        setup.l2Provider.v5.connection.url,
        setup.l1Provider.v5.connection.url,
        setup.l1Signer.privateKey,
        await childToParentRewardRouter.getAddress(),
        0,
        0,
        1000
      ).redeemChildToParentMessages()

      // funds should be in parentToChildRewardRouter now
      expect(
        (
          await testToken.balanceOf(parentToChildRewardRouter.getAddress())
        ).toHexString()
      ).to.eq(tokenValue.toHexString())
    })

    it('routes runds to destination ', async () => {
      await checkAndRouteFunds(
        await testToken.getAddress(),
        setup.l1Signer,
        setup.l2Signer,
        await parentToChildRewardRouter.getAddress(),
        0n
      )
      // funds should be in destination
      expect((await l2TestToken.balanceOf(destination)).toHexString()).to.eq(
        tokenValue.toHexString()
      )
    })
  })
})
