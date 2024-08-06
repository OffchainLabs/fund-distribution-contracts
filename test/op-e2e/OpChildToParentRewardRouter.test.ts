import { expect } from 'chai'
import {
  ParentToChildRewardRouter__factory,
  ParentToChildRewardRouter,
  ChildToParentRewardRouter,
  RewardDistributor__factory,
  RewardDistributor,
  ArbChildToParentRewardRouter__factory,
  IERC20__factory,
  IERC20,
  OpChildToParentRewardRouter,
  OpChildToParentRewardRouter__factory,
} from '../../typechain-types'
import { BigNumber } from 'ethers-v5'
import {
  ArbChildToParentMessageRedeemer,
  OpChildToParentMessageRedeemer,
} from '../../scripts/src-ts/FeeRouter/ChildToParentMessageRedeemer'
import { checkAndRouteFunds } from '../../scripts/src-ts/FeeRouter/checkAndRouteFunds'
import { Erc20Bridger } from '../../lib/arbitrum-sdk/src'
import { ContractFactory, ethers, parseEther, ZeroAddress } from 'ethers'
import TestTokenArtifact from '../../out/TestToken.sol/TestToken.json'
import { DoubleProvider, DoubleWallet } from '../../scripts/template/util'
import { createWalletClient, defineChain, http } from 'viem'
import { localhost, mainnet } from 'viem/chains'
import { chainConfig, walletActionsL1 } from 'viem/op-stack'

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
    l2OutputOracle: {
      900: {
        address: '0x19652082F846171168Daf378C4fD3ee85a0D4A60',
      },
    },
    portal: {
      900: {
        address: '0x6509f2a854BA7441039fCE3b959d5bAdd2fFCFCD',
      },
    },
    l1StandardBridge: {
      900: {
        address: '0xfe36E31dFE8Cb3A3Aa0CB9f35B191DdB5451b090',
      },
    },
    disputeGameFactory: {
      900: {
        address: '0xD34052d665891976eE71E097EaAF03Df51e9e3d5',
      },
    },
  },
  sourceId: 900,
})

const wait = (ms: number) => new Promise(res => setTimeout(res, ms))

const l1StdBridgeAddr = devnetL2.contracts.l1StandardBridge[900].address

const l1StdBridgeIface = new ethers.Interface([
  'function depositERC20(address _l1Token, address _l2Token, uint256 _amount, uint32 _minGasLimit, bytes calldata _extraData)',
])

async function deployTestToken(signer: DoubleWallet) {
  const testToken = await new ContractFactory(
    TestTokenArtifact.abi,
    TestTokenArtifact.bytecode,
    signer
  ).deploy(parseEther('100'))
  await testToken.waitForDeployment()
  return IERC20__factory.connect(await testToken.getAddress(), signer)
}

describe('Router e2e test', () => {
  const funderPk =
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
  const pk = DoubleWallet.createRandom().privateKey

  const funder = new DoubleWallet(
    funderPk,
    new DoubleProvider('http://127.0.0.1:8545') // todo: use configs
  )
  const parentChainSigner = new DoubleWallet(
    pk,
    new DoubleProvider('http://127.0.0.1:8545')
  )
  const childChainSigner = new DoubleWallet(
    pk,
    new DoubleProvider('http://127.0.0.1:9545')
  )

  let childToParentRewardRouter: OpChildToParentRewardRouter
  let l1Token: IERC20
  let l2Token: IERC20

  const destination = DoubleWallet.createRandom().address

  async function depositTokensAndETHToL2() {
    // deposit ETH
    await (await parentChainSigner.sendTransaction({
      to: l1StdBridgeAddr,
      value: parseEther('50'),
    })).wait()

    // wait for eth
    while (
      (await childChainSigner.provider.getBalance(childChainSigner.address)) ===
      0n
    ) {
      await wait(1000)
    }


    const l1Addr = await l1Token.getAddress()

    const iface = new ethers.Interface([
      'function createOptimismMintableERC20(address,string,string)',
    ])

    const createRec = await (
      await childChainSigner.sendTransaction({
        to: '0x4200000000000000000000000000000000000012',
        data: iface.encodeFunctionData('createOptimismMintableERC20', [
          l1Addr,
          'L2 Token',
          'L2TKN',
        ]),
      })
    ).wait()

    const l2AddrBytes32 = createRec!.logs[0].topics[2]
    const l2Addr = l2AddrBytes32.slice(0, 2) + l2AddrBytes32.slice(26)

    l2Token = IERC20__factory.connect(l2Addr, childChainSigner)

    // approve
    const approvalTx = await l1Token
      .connect(parentChainSigner)
      .approve(l1StdBridgeAddr, parseEther('50'))
    await approvalTx.wait()

    // deposit
    const depositTx = await parentChainSigner.sendTransaction({
      to: l1StdBridgeAddr,
      data: l1StdBridgeIface.encodeFunctionData('depositERC20', [
        l1Addr,
        l2Addr,
        parseEther('50'),
        0,
        '0x',
      ]),
    })
    await depositTx.wait()

    // wait for tokens
    while ((await l2Token.balanceOf(childChainSigner.address)) === 0n) {
      await wait(1000)
    }
  }

  async function printBalances() {
    console.log(
      'parent signer eth balance',
      await parentChainSigner.provider.getBalance(parentChainSigner.address)
    )
    console.log(
      'child signer eth balance',
      await childChainSigner.provider.getBalance(childChainSigner.address)
    )
    console.log(
      'router eth balance',
      await childChainSigner.provider.getBalance(
        await childToParentRewardRouter.getAddress()
      )
    )
    console.log(
      'destination eth balance',
      await parentChainSigner.provider.getBalance(destination)
    )
  }

  before(async () => {
    // fund the parent chain signer
    await (await funder.sendTransaction({
      to: parentChainSigner.address,
      value: parseEther('100'),
    })).wait()

    console.log('funded parent chain signer')

    l1Token = await deployTestToken(parentChainSigner)

    // also sets l2Token
    await depositTokensAndETHToL2()

    childToParentRewardRouter = await new OpChildToParentRewardRouter__factory(
      childChainSigner
    ).deploy(destination, 10, l1Token.getAddress(), l2Token.getAddress())

    await childToParentRewardRouter.waitForDeployment()

    console.log(
      'childToParentRewardRouter',
      await childToParentRewardRouter.getAddress()
    )
    console.log('l2Token', await l2Token.getAddress())
    console.log('l1Token', await l1Token.getAddress())
    console.log('destination', destination)

    await printBalances()
  })

  describe('ETH to Parent', () => {
    const ethValue = parseEther('1')
    it('should initiate a withdrawal on receipt of ETH', async () => {
      // send eth to the router
      const tx = await childChainSigner.sendTransaction({
        to: childToParentRewardRouter.getAddress(),
        value: ethValue,
      })
      const rec = (await tx.wait())!

      // make sure it emits the events
      // todo: actually check these in code
      console.log(rec.logs.map(l => `${l.address} ${l.topics[0]}`).join('\n'))

      console.log(rec.logs)
      await printBalances()
    })

    it('should redeem the funds on the parent chain', async () => {
      const redeemer = new OpChildToParentMessageRedeemer(
        childChainSigner.doubleProvider,
        parentChainSigner,
        await childToParentRewardRouter.getAddress(),
        0,
        ':memory:',
        devnetL2,
        devnetL1
      )

      while (true) {
        await printBalances()
        await redeemer.redeemChildToParentMessages()

        const balance = await parentChainSigner.provider.getBalance(destination)

        console.log(balance)

        if (balance === ethValue) {
          break
        }

        if (balance > 0) {
          throw new Error('unexpected balance')
        }

        await wait(10_000)
      }
    })
  })
})
