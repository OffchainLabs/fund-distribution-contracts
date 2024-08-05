import dotenv from 'dotenv'
import yargs from 'yargs'
import { distributeRewards } from '../lib'
import { DoubleProvider, DoubleWallet } from '../../template/util'
dotenv.config()

const CHILD_CHAIN_PK = process.env.CHILD_CHAIN_PK

if (!CHILD_CHAIN_PK) throw new Error('Need CHILD_CHAIN_PK')

const options = yargs(process.argv.slice(2))
  .options({
    rpcURL: { type: 'string', demandOption: true },
    rewardDistAddr: { type: 'string', demandOption: true },
    minBalanceEther: { type: 'number', demandOption: false, default: 0 },
  })
  .parseSync()

;(async () => {
  await distributeRewards(
    new DoubleWallet(CHILD_CHAIN_PK, new DoubleProvider(options.rpcURL)),
    options.rewardDistAddr,
    options.minBalanceEther
  )
})()
