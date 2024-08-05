import dotenv from 'dotenv'
import yargs from 'yargs'
import { JsonRpcProvider } from '@ethersproject/providers'
import { checkAndRouteFunds } from '../FeeRouter/checkAndRouteFunds'
import { DoubleProvider, DoubleWallet } from '../../template/util'
import { parseEther } from 'ethers'

dotenv.config()

const PARENT_CHAIN_PK = process.env.PARENT_CHAIN_PK
if (!PARENT_CHAIN_PK) throw new Error('Need PARENT_CHAIN_PK')

const CHILD_CHAIN_PK = process.env.CHILD_CHAIN_PK
if (!CHILD_CHAIN_PK) throw new Error('Need CHILD_CHAIN_PK')

const options = yargs(process.argv.slice(2))
  .options({
    parentRPCUrl: { type: 'string', demandOption: true },
    childRPCUrl: { type: 'string', demandOption: true },
    ETHorTokenAddress: { type: 'string', demandOption: true },
    parentToChildRewardRouterAddr: { type: 'string', demandOption: true },
    minBalanceEther: { type: 'number', demandOption: false, default: 0 },
  })
  .parseSync()

;(async () => {
  const parentChildSigner = new DoubleWallet(
    PARENT_CHAIN_PK,
    new DoubleProvider(options.parentRPCUrl)
  )
  console.log(`Signing with ${parentChildSigner.address} on parent chain 
    ${(await parentChildSigner.provider.getNetwork()).chainId}'`)

  const childChainSigner = new DoubleWallet(
    PARENT_CHAIN_PK,
    new DoubleProvider(options.childRPCUrl)
  )

  console.log(`Signing with ${childChainSigner.address} on child chain 
  ${(await childChainSigner.provider.getNetwork()).chainId}'`)
  await checkAndRouteFunds(
    options.ETHorTokenAddress,
    parentChildSigner,
    childChainSigner,
    options.parentToChildRewardRouterAddr,
    parseEther(String(options.minBalanceEther))
  )
  console.log('done')
})()
