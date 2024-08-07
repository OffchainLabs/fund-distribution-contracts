import {
  ChildToParentRewardRouter__factory,
  ChildToParentRewardRouter,
} from '../../../typechain-types'
import { L2ToL1TxEvent } from '../../../lib/arbitrum-sdk/src/lib/abi/ArbSys'

import {
  L2TransactionReceipt,
  L2ToL1Message,
  L2ToL1MessageStatus,
} from '../../../lib/arbitrum-sdk/src'
import { DoubleProvider, DoubleWallet } from '../../template/util'
import { EventArgs } from '../../../lib/arbitrum-sdk/src/lib/dataEntities/event'
import { LogCache } from 'fetch-logs-with-cache'

export default class ChildToParentMessageRedeemer {
  public readonly childToParentRewardRouter: ChildToParentRewardRouter
  private readonly logCache: LogCache
  constructor(
    public readonly childChainProvider: DoubleProvider,
    public readonly parentChainSigner: DoubleWallet,
    public readonly childToParentRewardRouterAddr: string,
    public readonly startBlock: number,
    public readonly logsDbPath: string
  ) {
    this.childToParentRewardRouter = ChildToParentRewardRouter__factory.connect(
      childToParentRewardRouterAddr,
      childChainProvider
    )
    this.logCache = new LogCache(logsDbPath)
  }

  public async redeemChildToParentMessages() {
    const logs = await this.logCache.getLogs(this.childChainProvider, {
      fromBlock: this.startBlock,
      address: await this.childToParentRewardRouter.getAddress(),
      topics: [
        this.childToParentRewardRouter.filters.FundsRouted().fragment.topicHash,
      ],
    })
    if (logs.length) {
      console.log(
        `Found ${logs.length} route events between blocks ${this.startBlock} and latest`
      )
    }

    for (const log of logs) {
      const arbTransactionRec = new L2TransactionReceipt(
        await this.childChainProvider.v5.getTransactionReceipt(
          log.transactionHash
        )
      )
      const l2ToL1Events =
        arbTransactionRec.getL2ToL1Events() as EventArgs<L2ToL1TxEvent>[]

      if (l2ToL1Events.length != 1) {
        throw new Error('Only 1 l2 to l1 message per tx supported')
      }

      for (const l2ToL1Event of l2ToL1Events) {
        const l2ToL1Message = L2ToL1Message.fromEvent(
          this.parentChainSigner.v5,
          l2ToL1Event
        )

        const status = await l2ToL1Message.status(this.childChainProvider.v5)
        switch (status) {
          case L2ToL1MessageStatus.CONFIRMED: {
            console.log(l2ToL1Event.hash, 'confirmed; executing:')
            const rec = await (
              await l2ToL1Message.execute(this.childChainProvider.v5)
            ).wait(2)
            console.log(`${l2ToL1Event.hash} executed:`, rec.transactionHash)
            break
          }
          case L2ToL1MessageStatus.EXECUTED: {
            console.log(`${l2ToL1Event.hash} already executed`)
            break
          }
          case L2ToL1MessageStatus.UNCONFIRMED: {
            console.log(`${l2ToL1Event.hash} not yet confirmed`)
            break
          }
          default: {
            throw new Error(`Unhandled L2ToL1MessageStatus case: ${status}`)
          }
        }
      }
    }
  }
}
