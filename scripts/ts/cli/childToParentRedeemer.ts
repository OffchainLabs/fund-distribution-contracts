import dotenv from 'dotenv'
import yargs from 'yargs'
import {
  ArbChildToParentMessageRedeemer,
  OpChildChainConfig,
  OpChildToParentMessageRedeemer,
  ChildToParentMessageRedeemer,
} from '../FeeRouter/ChildToParentMessageRedeemer'
import chains from 'viem/chains'
import { registerCustomArbitrumNetwork } from '@arbitrum/sdk'
import { DoubleProvider, DoubleWallet } from '../../template/util'

dotenv.config()

const PARENT_CHAIN_PK = process.env.PARENT_CHAIN_PK

if (!PARENT_CHAIN_PK) throw new Error('Need PARENT_CHAIN_PK')

const options = yargs(process.argv.slice(2))
  .options({
    parentRPCUrl: { type: 'string', demandOption: true },
    childRPCUrl: { type: 'string', demandOption: true },
    childToParentRewardRouterAddr: { type: 'string', demandOption: true },
    blockLag: { type: 'number', demandOption: false, default: 5 },
    childChainStartBlock: { type: 'number', demandOption: false, default: 0 },
    oneOff: {
      type: 'boolean',
      demandOption: false,
      default: false,
      description:
        'Runs continuously if false, runs once and terminates if true',
    },
    opStack: { type: 'boolean', demandOption: false, default: false },
  })
  .parseSync()

// register a custom Orbit chain not in the SDK's built-in list
const childNetworkJson = process.env.CHILD_NETWORK_JSON
if (childNetworkJson) {
  const network = JSON.parse(childNetworkJson)
  registerCustomArbitrumNetwork(network)
  console.log(`Registered custom child network ${network.chainId}`)
}

;(async () => {
  const parentChildSigner = new DoubleWallet(
    PARENT_CHAIN_PK,
    new DoubleProvider(options.parentRPCUrl)
  )
  const childChainProvider = new DoubleProvider(options.childRPCUrl)
  const parentChainId = (await parentChildSigner.provider.getNetwork()).chainId
  const childChainId = (await childChainProvider.getNetwork()).chainId
  console.log(
    `Signing with ${parentChildSigner.address} on parent chain ${parentChainId}'`
  )

  let redeemer: ChildToParentMessageRedeemer
  if (options.opStack) {
    const childChain = Object.values(chains).find(
      c => c.id === Number(childChainId)
    )
    const parentChain = Object.values(chains).find(
      c => c.id === Number(parentChainId)
    )

    if (!childChain || !parentChain) {
      throw new Error('Unsupported chain')
    }

    redeemer = new OpChildToParentMessageRedeemer(
      options.childRPCUrl,
      options.parentRPCUrl,
      PARENT_CHAIN_PK,
      options.childToParentRewardRouterAddr,
      options.blockLag,
      options.childChainStartBlock,
      childChain as OpChildChainConfig,
      parentChain
    )
  } else {
    redeemer = new ArbChildToParentMessageRedeemer(
      options.childRPCUrl,
      options.parentRPCUrl,
      PARENT_CHAIN_PK,
      options.childToParentRewardRouterAddr,
      options.blockLag,
      options.childChainStartBlock
    )
  }
  await redeemer.run(options.oneOff)
})()
