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

import {
  Chain,
  ChainContract,
  createPublicClient,
  createWalletClient,
  Hex,
  http,
  publicActions,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import {
  getWithdrawals,
  publicActionsL1,
  publicActionsL2,
  walletActionsL1,
} from 'viem/op-stack'

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

export type OpChildChainConfig = Chain & {
  contracts: {
    portal: { [x: number]: ChainContract }
    disputeGameFactory: { [x: number]: ChainContract }
    l2OutputOracle: { [x: number]: ChainContract }
  }
}

export class OpChildToParentMessageRedeemer extends ChildToParentMessageRedeemer {
  public readonly childChainViemProvider
  public readonly parentChainViemSigner

  constructor(
    childChainProvider: DoubleProvider,
    parentChainSigner: DoubleWallet,
    childToParentRewardRouterAddr: string,
    startBlock: number,
    logsDbPath: string,
    public readonly childChainViem: OpChildChainConfig,
    public readonly parentChainViem: Chain
  ) {
    super(
      childChainProvider,
      parentChainSigner,
      childToParentRewardRouterAddr,
      startBlock,
      logsDbPath
    )

    this.childChainViemProvider = createPublicClient({
      chain: childChainViem,
      transport: http(this.childChainProvider.v5.connection.url),
    }).extend(publicActionsL2())

    this.parentChainViemSigner = createWalletClient({
      chain: parentChainViem,
      account: privateKeyToAccount(
        this.parentChainSigner.privateKey as `0x${string}`
      ),
      transport: http(this.parentChainSigner.v5.provider.connection.url),
    })
      .extend(publicActions)
      .extend(walletActionsL1())
      .extend(publicActionsL1())
  }

  public async redeemChildToParentMessages() {
    const logs = await this._getLogs()

    for (const log of logs) {
      const receipt = await this.childChainViemProvider.getTransactionReceipt({
        hash: log.transactionHash as Hex,
      })

      // 'waiting-to-prove'
      // 'ready-to-prove'
      // 'waiting-to-finalize'
      // 'ready-to-finalize'
      // 'finalized'
      const status = await this.parentChainViemSigner.getWithdrawalStatus({
        receipt,
        targetChain: this.childChainViemProvider.chain,
      })

      console.log(`${log.transactionHash} ${status}`)

      if (status === 'ready-to-prove') {
        // 1. Wait until the withdrawal is ready to prove.
        const { output, withdrawal } =
          await this.parentChainViemSigner.waitToProve({
            receipt,
            targetChain: this.childChainViemProvider.chain,
          })
        // 2. Build parameters to prove the withdrawal on the L2.
        const args = await this.childChainViemProvider.buildProveWithdrawal({
          output,
          withdrawal,
        })
        // 3. Prove the withdrawal on the L1.
        const hash = await this.parentChainViemSigner.proveWithdrawal(args)
        // 4. Wait until the prove withdrawal is processed.
        await this.parentChainViemSigner.waitForTransactionReceipt({
          hash,
        })

        console.log(`${log.transactionHash} proved:`, hash)
      } else if (status === 'ready-to-finalize') {
        const [withdrawal] = getWithdrawals(receipt)

        // 1. Wait until the withdrawal is ready to finalize. (done)

        // 2. Finalize the withdrawal.
        const hash = await this.parentChainViemSigner.finalizeWithdrawal({
          targetChain: this.childChainViemProvider.chain,
          withdrawal,
        })

        // 3. Wait until the withdrawal is finalized.
        await this.parentChainViemSigner.waitForTransactionReceipt({
          hash,
        })

        console.log(`${log.transactionHash} finalized:`, hash)
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
