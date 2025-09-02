// Follow instructions to set up a local devnet here: https://docs.optimism.io/chain/testing/dev-node

import { defineChain } from "viem"
import { chainConfig } from "viem/op-stack"
import { OpChildToParentMessageRedeemer } from "../../scripts/ts/FeeRouter/ChildToParentMessageRedeemer"
import { IERC20__factory, OpChildToParentRewardRouter, IERC20, OpChildToParentRewardRouter__factory } from "../../typechain-types"
import { Contract, ContractFactory, Interface, parseEther } from "ethers"
import { DoubleProvider, DoubleWallet } from "../../scripts/template/util"

import TestTokenAbi from '../../out/TestToken.sol/TestToken.json'

const devnetL1 = defineChain({
  id: 900,
  name: 'DevnetL1',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
  },
})

const devnetL2 = defineChain({
  ...chainConfig,
  id: 901,
  name: 'DevnetL2',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:9545'],
    },
  },
  contracts: {
    ...chainConfig.contracts,
    portal: {
      900: {
        address: '0xA439B64360C875951478b0Cf77698038df331255',
      },
    },
    l1StandardBridge: {
      900: {
        address: '0x9D34A2610Ea283f6d9AE29f9Cad82e00c4d38507',
      },
    },
    disputeGameFactory: {
      900: {
        address: '0xeCb92a686D1ab066fc4E559A305FEB75DD512377',
      },
    },
  },
  sourceId: 900,
})

const wait = (ms: number) => new Promise(res => setTimeout(res, ms))

const l1StdBridgeAddr = devnetL2.contracts.l1StandardBridge[900].address

const l1StdBridgeIface = new Interface([
  'function depositERC20(address _l1Token, address _l2Token, uint256 _amount, uint32 _minGasLimit, bytes calldata _extraData)',
])

async function deployTestToken(signer: DoubleWallet) {
  // const testToken = await new connect(signer).deploy()
  const testToken = (await new ContractFactory(
    TestTokenAbi.abi,
    TestTokenAbi.bytecode,
    signer
  ).deploy()) as Contract
  await testToken.deployed()
  await (await testToken.mint()).wait()
  return IERC20__factory.connect(await testToken.getAddress(), signer)
}

describe('Router e2e test', () => {
  const funderPk =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
  const pk = DoubleWallet.createRandom().privateKey

  const funder = new DoubleWallet(
    funderPk,
    new DoubleProvider(devnetL1.rpcUrls.default.http[0]) // todo: use configs
  )
  const parentChainSigner = new DoubleWallet(
    pk,
    new DoubleProvider(devnetL1.rpcUrls.default.http[0])
  )
  const childChainSigner = new DoubleWallet(
    pk,
    new DoubleProvider(devnetL2.rpcUrls.default.http[0])
  )

  let childToParentRewardRouter: OpChildToParentRewardRouter
  let l1Token: IERC20
  let l2Token: IERC20

  const destination = DoubleWallet.createRandom().address

  before(async () => {
    // fund the parent chain signer
    await (
      await funder.sendTransaction({
        to: parentChainSigner.address,
        value: parseEther('100'),
      })
    ).wait()
    console.log('funded parent chain signer')

    // deposit ETH
    await (
      await parentChainSigner.sendTransaction({
        to: l1StdBridgeAddr,
        value: parseEther('50'),
      })
    ).wait()
    console.log('deposited ETH')

    // wait for eth
    while (
      (await childChainSigner.provider.getBalance(childChainSigner.address)) === (
        0n
      )
    ) {
      await wait(1000)
    }
    console.log('eth received')

    l1Token = await deployTestToken(parentChainSigner)
    const l1Addr = await l1Token.getAddress()
    console.log('deployed test token')

    const opTokenFactoryIface = new Interface([
      'function createOptimismMintableERC20(address,string,string)',
    ])

    const createRec = await (
      await childChainSigner.sendTransaction({
        to: '0x4200000000000000000000000000000000000012',
        data: opTokenFactoryIface.encodeFunctionData(
          'createOptimismMintableERC20',
          [l1Addr, 'L2 Token', 'L2TKN']
        ),
      })
    ).wait()
    console.log('created L2 token')

    const l2AddrBytes32 = createRec!.logs[0].topics[2]
    const l2Addr = l2AddrBytes32.slice(0, 2) + l2AddrBytes32.slice(26)

    l2Token = IERC20__factory.connect(l2Addr, childChainSigner)

    // approve
    const approvalTx = await l1Token
      .connect(parentChainSigner)
      .approve(l1StdBridgeAddr, 50n)
    await approvalTx.wait()
    console.log('approved tokens')

    // deposit
    const depositTx = await parentChainSigner.sendTransaction({
      to: l1StdBridgeAddr,
      data: l1StdBridgeIface.encodeFunctionData('depositERC20', [
        l1Addr,
        l2Addr,
        50n,
        0,
        '0x',
      ]),
    })
    await depositTx.wait()
    console.log('deposited tokens')

    // wait for tokens
    while ((await l2Token.balanceOf(childChainSigner.address)) === 0n) {
      await wait(1000)
    }
    console.log('tokens received')

    childToParentRewardRouter = await new OpChildToParentRewardRouter__factory(
      childChainSigner
    ).deploy(destination, 10, l1Token.getAddress(), l2Token.getAddress())

    await childToParentRewardRouter.deploymentTransaction()!.wait()
    console.log('deployed child to parent router')
  })

  describe('ETH to Parent', () => {
    const ethValue = 1n
    it('should initiate a withdrawal on receipt of ETH', async () => {
      // send eth to the router
      const tx = await childChainSigner.sendTransaction({
        to: childToParentRewardRouter.getAddress(),
        value: ethValue,
      })
      const rec = (await tx.wait())!

      // make sure it emits the event
      const fundsRoutedLog = rec.logs.find(
        log =>
          log.topics[0] ===
          childToParentRewardRouter.interface.getEvent('FundsRouted').topicHash
      )

      if (!fundsRoutedLog) {
        throw new Error('expected FundsRouted log')
      }
    })

    it('should redeem the funds on the parent chain', async () => {
      const redeemer = new OpChildToParentMessageRedeemer(
        devnetL2.rpcUrls.default.http[0],
        devnetL1.rpcUrls.default.http[0],
        pk,
        await childToParentRewardRouter.getAddress(),
        0,
        0,
        devnetL2,
        devnetL1
      )

      // eslint-disable-next-line no-constant-condition
      while (true) {
        await redeemer.redeemChildToParentMessages(true)

        const balance = await parentChainSigner.provider.getBalance(destination)

        if (balance === (ethValue)) {
          break
        }

        if (balance > (0n)) {
          throw new Error('unexpected balance')
        }

        await wait(10_000)
      }
    })
  })

  describe('ERC20 to Parent', () => {
    const erc20Amount = 1n

    it('should initiate a withdrawal', async () => {
      // send tokens to the router
      await (
        await l2Token
          .connect(childChainSigner)
          .transfer(childToParentRewardRouter.getAddress(), erc20Amount)
      ).wait()

      const pokeTx = await childToParentRewardRouter
        .connect(childChainSigner)
        .routeToken()
      const pokeRec = (await pokeTx.wait())!

      // make sure it emits the event
      const fundsRoutedLog = pokeRec.logs.find(
        log =>
          log.topics[0] ===
          childToParentRewardRouter.interface.getEvent('FundsRouted').topicHash
      )

      if (!fundsRoutedLog) {
        throw new Error('expected FundsRouted log')
      }
    })

    it('should redeem the funds on the parent chain', async () => {
      const redeemer = new OpChildToParentMessageRedeemer(
        devnetL2.rpcUrls.default.http[0],
        devnetL1.rpcUrls.default.http[0],
        pk,
        await childToParentRewardRouter.getAddress(),
        0,
        0,
        devnetL2,
        devnetL1
      )

      // eslint-disable-next-line no-constant-condition
      while (true) {
        await redeemer.redeemChildToParentMessages(true)

        const balance = await l1Token.balanceOf(destination)

        if (balance === (erc20Amount)) {
          break
        }

        if (balance > 0n) {
          throw new Error('unexpected balance')
        }

        await wait(10_000)
      }
    })
  })
})
