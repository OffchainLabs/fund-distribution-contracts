import { expect } from 'chai'
import { TestSetup, testSetup } from './testSetup'
import {
  ParentToChildRewardRouter__factory,
  ParentToChildRewardRouter,
  ChildToParentRewardRouter,
  RewardDistributor__factory,
  RewardDistributor,
  ArbChildToParentRewardRouter__factory,
  IERC20__factory,
  IERC20,
} from '../../typechain-types'
import { BigNumber } from 'ethers-v5'
import ChildToParentMessageRedeemer from '../../scripts/src-ts/FeeRouter/ChildToParentMessageRedeemer'
import { checkAndRouteFunds } from '../../scripts/src-ts/FeeRouter/checkAndRouteFunds'
import { Erc20Bridger } from '../../lib/arbitrum-sdk/src'
import { ContractFactory, Wallet, parseEther } from 'ethers'
import TestTokenArtifact from '../../out/TestToken.sol/TestToken.json'

async function deployTestToken(signer: Wallet) {
  const testToken = await new ContractFactory(
    TestTokenArtifact.abi,
    TestTokenArtifact.bytecode,
    signer
  ).deploy(parseEther('1000'))
  await testToken.waitForDeployment()
  return IERC20__factory.connect(await testToken.getAddress(), signer)
}

describe('Router e2e test', () => {
  let setup: TestSetup
  let parentToChildRewardRouter: ParentToChildRewardRouter
  let childToParentRewardRouter: ChildToParentRewardRouter
  let rewardDistributor: RewardDistributor
  let testToken: IERC20
  let l2TestToken: IERC20
  const destination = Wallet.createRandom().address

  console.log('destination', destination)

  before(async () => {
    setup = await testSetup()
    console.log(
      'using L1 wallet:',
      setup.l1Signer.v5.address,
      await setup.l1Provider.v6.getBalance(setup.l1Signer.v5.address)
    )
    console.log(
      'using L2 wallet:',
      setup.l2Signer.v5.address,
      await setup.l2Provider.v6.getBalance(setup.l2Signer.v5.address)
    )

    testToken = await deployTestToken(setup.l1Signer.v6)
    console.log('Test token L1 deployed', await testToken.getAddress())

    // Initial token deposit:
    const erc20Bridger = new Erc20Bridger(setup.l2Network)

    await (
      await erc20Bridger.approveToken({
        erc20L1Address: await testToken.getAddress(),
        l1Signer: setup.l1Signer.v5,
      })
    ).wait()
    const depositRes = await erc20Bridger.deposit({
      amount: BigNumber.from(1000),
      erc20L1Address: await testToken.getAddress(),
      l1Signer: setup.l1Signer.v5,
      l2Provider: setup.l2Provider.v5,
    })

    const depositRec = await depositRes.wait()

    console.log('waiting for retryables')

    await depositRec.waitForL2(setup.l2Signer.v5)
    const l2TokenAddress = await erc20Bridger.getL2ERC20Address(
      await testToken.getAddress(),
      setup.l1Provider.v5
    )

    console.log('L2 test token:', l2TokenAddress)

    l2TestToken = IERC20__factory.connect(l2TokenAddress, setup.l2Signer.v6)

    // deploy parent to child
    console.log('Deploying parentToChildRewardRouter:')

    parentToChildRewardRouter = await new ParentToChildRewardRouter__factory(
      setup.l1Signer.v6
    ).deploy(
      setup.l2Network.tokenBridge.l1GatewayRouter,
      destination,
      10,
      100000000,
      300000
    )
    await parentToChildRewardRouter.waitForDeployment()
    console.log(
      'ParentToChildRewardRouter deployed',
      await parentToChildRewardRouter.getAddress()
    )

    console.log('Deploying childToParentRewardRouter:')

    // deploy child to parent
    childToParentRewardRouter = await new ArbChildToParentRewardRouter__factory(
      setup.l2Signer.v6
    ).deploy(
      await parentToChildRewardRouter.getAddress(),
      10,
      await testToken.getAddress(),
      l2TokenAddress,
      setup.l2Network.tokenBridge.l2GatewayRouter
    )
    await childToParentRewardRouter.waitForDeployment()
    console.log(
      'childToParentRewardRouter deployed:',
      await childToParentRewardRouter.getAddress()
    )

    // deploy fund distributor
    console.log('Deploying rewardDistributor:')

    rewardDistributor = await new RewardDistributor__factory(
      setup.l2Signer.v6
    ).deploy([await childToParentRewardRouter.getAddress()], [10000])
    await rewardDistributor.waitForDeployment()
    console.log(
      'Reward Distributor deployed:',
      await rewardDistributor.getAddress()
    )
  })

  it('should have the correct network information', async () => {
    expect(setup.l1Network.chainID).to.eq(1337)
    expect(setup.l2Network.chainID).to.eq(412346)
  })

  describe('e2e eth routing test', async () => {
    const ethValue = parseEther('.23')
    it('destination has initial balance of 0', async () => {
      const initialBal = await setup.l2Provider.v6.getBalance(destination)
      expect(initialBal).to.eq(0n)
    })

    // fund reward distributor
    it('funds and pokes reward distributor', async () => {
      await (
        await setup.l2Signer.v6.sendTransaction({
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
        await setup.l2Provider.v6.getBalance(rewardDistributor.getAddress())
      ).to.equal(0n)

      expect(
        await setup.l2Provider.v6.getBalance(
          childToParentRewardRouter.getAddress()
        )
      ).to.equal(0n)
    })

    it('redeems l2 to l1 message', async () => {
      await new ChildToParentMessageRedeemer(
        setup.l2Provider,
        setup.l1Signer,
        await childToParentRewardRouter.getAddress(),
        0,
        0,
        1000
      ).redeemChildToParentMessages()

      // funds should be in parentToChildRewardRouter now
      expect(
        await setup.l1Provider.v6.getBalance(
          await parentToChildRewardRouter.getAddress()
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
      expect(await setup.l2Provider.v6.getBalance(destination)).to.eq(ethValue)
    })
  })

  describe('token routing test', async () => {
    const tokenValue = 231n
    it('destination has initial balance of 0', async () => {
      const initialBal = await l2TestToken.balanceOf(destination)

      expect(initialBal).to.eq(0n)
    })

    it('funds and pokes child to parent router', async () => {
      await (
        await l2TestToken.transfer(
          childToParentRewardRouter.getAddress(),
          tokenValue
        )
      ).wait()

      // prePokeBlock = setup.l2
      await (await childToParentRewardRouter.routeToken()).wait()
      expect(
        await l2TestToken.balanceOf(
          await childToParentRewardRouter.getAddress()
        )
      ).to.eq(0n)
    })

    it('redeems l2 to l1 message', async () => {
      await new ChildToParentMessageRedeemer(
        setup.l2Provider,
        setup.l1Signer,
        await childToParentRewardRouter.getAddress(),
        0,
        0,
        1000
      ).redeemChildToParentMessages()

      // funds should be in parentToChildRewardRouter now
      expect(
        await testToken.balanceOf(await parentToChildRewardRouter.getAddress())
      ).to.eq(tokenValue)
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
      expect(await l2TestToken.balanceOf(destination)).to.eq(tokenValue)
    })
  })
})
