import dotenv from 'dotenv'
import yargs from 'yargs'
import {
  ArbChildToParentMessageRedeemer,
  OpChildChainConfig,
  OpChildToParentMessageRedeemer,
} from '../FeeRouter/ChildToParentMessageRedeemer'
import { DoubleProvider, DoubleWallet } from '../../template/util'
import chains from 'viem/chains'

dotenv.config()

const PARENT_CHAIN_PK = process.env.PARENT_CHAIN_PK

if (!PARENT_CHAIN_PK) throw new Error('Need PARENT_CHAIN_PK')

const options = yargs(process.argv.slice(2))
  .options({
    parentRPCUrl: { type: 'string', demandOption: true },
    childRPCUrl: { type: 'string', demandOption: true },
    childToParentRewardRouterAddr: { type: 'string', demandOption: true },
    childChainStartBlock: { type: 'number', demandOption: false, default: 0 },
    logsDbPath: { type: 'string', demandOption: false, default: '.logs.db' },
    opStack: { type: 'boolean', demandOption: false, default: false },
  })
  .parseSync()

;(async () => {
  const parentChildSigner = new DoubleWallet(
    PARENT_CHAIN_PK,
    new DoubleProvider(options.parentRPCUrl)
  )
  const childChainProvider = new DoubleProvider(options.childRPCUrl)
  const parentChainId = (await parentChildSigner.v5.provider.getNetwork())
    .chainId
  const childChainId = (await childChainProvider.v5.getNetwork()).chainId

  console.log(
    `Signing with ${parentChildSigner.address} on parent chain ${parentChainId}`
  )

  if (options.opStack) {
    const childChain = Object.values(chains).find(
      c => c.id === childChainId
    )
    const parentChain = Object.values(chains).find(
      c => c.id === parentChainId
    )

    if (!childChain || !parentChain) {
      throw new Error('Unsupported chain')
    }

    await new OpChildToParentMessageRedeemer(
      new DoubleProvider(options.childRPCUrl),
      parentChildSigner,
      options.childToParentRewardRouterAddr,
      options.childChainStartBlock,
      options.logsDbPath,
      childChain as OpChildChainConfig,
      parentChain
    ).redeemChildToParentMessages()
  } else {
    await new ArbChildToParentMessageRedeemer(
      new DoubleProvider(options.childRPCUrl),
      parentChildSigner,
      options.childToParentRewardRouterAddr,
      options.childChainStartBlock,
      options.logsDbPath
    ).redeemChildToParentMessages()
  }
})()
