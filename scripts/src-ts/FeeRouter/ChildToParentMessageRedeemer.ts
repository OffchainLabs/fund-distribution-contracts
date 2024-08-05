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

import optimism, { MessageStatus } from '@eth-optimism/sdk'

abstract class ChildToParentMessageRedeemer {
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

  protected async _getLogs() {
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

    return logs
  }
}

export class OpChildToParentMessageRedeemer extends ChildToParentMessageRedeemer {
  public async redeemChildToParentMessages() {
    const logs = await this._getLogs()

    const messenger = new optimism.CrossChainMessenger({
      l1ChainId: (await this.parentChainSigner.v5.provider.getNetwork())
        .chainId,
      l2ChainId: (await this.childChainProvider.v5.getNetwork()).chainId,
      l1SignerOrProvider: this.parentChainSigner.v5,
      l2SignerOrProvider: this.childChainProvider.v5,
    })

    for (const log of logs) {
      const status = await messenger.getMessageStatus(log.transactionHash)

      switch (status) {
        case MessageStatus.STATE_ROOT_NOT_PUBLISHED:
          console.log(`${log.transactionHash} STATE_ROOT_NOT_PUBLISHED`)
          break
        case MessageStatus.READY_TO_PROVE:
          console.log(`${log.transactionHash} READY_TO_PROVE...`)
          await messenger.proveMessage(log.transactionHash)
          console.log(`${log.transactionHash} proved`)
          break
        case MessageStatus.IN_CHALLENGE_PERIOD:
          console.log(`${log.transactionHash} IN_CHALLENGE_PERIOD`)
          break
        case MessageStatus.READY_FOR_RELAY:
          console.log(`${log.transactionHash} READY_FOR_RELAY...`)
          await messenger.finalizeMessage(log.transactionHash)
          console.log(`${log.transactionHash} relayed`)
          break
        case MessageStatus.RELAYED:
          console.log(`${log.transactionHash} RELAYED`)
          break
        default:
          throw new Error(`Unhandled MessageStatus case: ${status}`)
      }
    }
  }
}

export class ArbChildToParentMessageRedeemer extends ChildToParentMessageRedeemer {
  public async redeemChildToParentMessages() {
    const logs = await this._getLogs()

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
            ).wait()
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
