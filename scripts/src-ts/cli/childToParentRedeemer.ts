import dotenv from 'dotenv'
import yargs from 'yargs'
import ChildToParentMessageRedeemer from '../FeeRouter/ChildToParentMessageRedeemer'
import { DoubleProvider, DoubleWallet } from '../../template/util'

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
  })
  .parseSync()

;(async () => {
  const parentChildSigner = new DoubleWallet(
    PARENT_CHAIN_PK,
    new DoubleProvider(options.parentRPCUrl)
  )
  console.log(`Signing with ${parentChildSigner.address} on parent chain 
  ${(await parentChildSigner.provider.getNetwork()).chainId}'`)

  const redeemer = new ChildToParentMessageRedeemer(
    new DoubleProvider(options.childRPCUrl),
    parentChildSigner,
    options.childToParentRewardRouterAddr,
    options.childChainStartBlock,
    options.logsDbPath
  )
  await redeemer.redeemChildToParentMessages()
})()
