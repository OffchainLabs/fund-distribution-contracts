import { JsonRpcProvider, Log } from "@ethersproject/providers";
import { Wallet } from "ethers";
import {
  ChildToParentRewardRouter__factory,
  ChildToParentRewardRouter,
} from "../../typechain-types";
import { L2ToL1TxEvent } from "../../lib/arbitrum-sdk/src/lib/abi/ArbSys";
import { EventArgs } from "../../lib/arbitrum-sdk/src/lib/dataEntities/event";

import {
  L2TransactionReceipt,
  L2ToL1Message,
  L2ToL1MessageStatus,
} from "../../lib/arbitrum-sdk/src";

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
  GetWithdrawalStatusReturnType,
  publicActionsL1,
  publicActionsL2,
  walletActionsL1,
} from 'viem/op-stack'

const wait = async (ms: number) => new Promise((res) => setTimeout(res, ms));

export abstract class ChildToParentMessageRedeemer {
  constructor(
    public readonly childChainRpc: string,
    public readonly parentChainRpc: string,
    protected readonly parentChainPrivateKey: string,
    public readonly childToParentRewardRouterAddr: string,
    public readonly blockLag: number,
    public startBlock: number = 0,
    public readonly retryDelay = 1000 * 60 * 10
  ) {}

  protected abstract _handleLogs(logs: Log[], oneOff: boolean): Promise<void>;

  public async redeemChildToParentMessages(oneOff = false) {
    const childChainProvider = new JsonRpcProvider(this.childChainRpc);

    const toBlock =
      (await childChainProvider.getBlockNumber()) - this.blockLag;
    const logs = await childChainProvider.getLogs({
      fromBlock: this.startBlock,
      toBlock: toBlock,
      address: this.childToParentRewardRouterAddr,
      topics: [ChildToParentRewardRouter__factory.createInterface().getEventTopic('FundsRouted')],
    });
    if (logs.length) {
      console.log(
        `Found ${logs.length} route events between blocks ${this.startBlock} and ${toBlock}`
      );
    }
    await this._handleLogs(logs, oneOff);
    return toBlock
  }

  public async run(oneOff = false) {
    while (true) {
      let toBlock = 0
      try {
        toBlock = await this.redeemChildToParentMessages(oneOff);
      } catch (err) {
        console.log("err", err);
      }
      if (oneOff) {
        break;
      } else {
        this.startBlock = toBlock + 1;
        await wait(1000 * 60 * 60);
      }
    }
  }
}

export class ArbChildToParentMessageRedeemer extends ChildToParentMessageRedeemer {
  protected async _handleLogs(logs: Log[], oneOff: boolean): Promise<void> {
    const childChainProvider = new JsonRpcProvider(this.childChainRpc);
    const parentChainSigner = new Wallet(this.parentChainPrivateKey, new JsonRpcProvider(this.parentChainRpc));
    for (let log of logs) {
      const arbTransactionRec = new L2TransactionReceipt(
        await childChainProvider.getTransactionReceipt(log.transactionHash)
      );
      let l2ToL1Events =
        arbTransactionRec.getL2ToL1Events() as EventArgs<L2ToL1TxEvent>[];

      if (l2ToL1Events.length != 1) {
        throw new Error("Only 1 l2 to l1 message per tx supported");
      }

      for (let l2ToL1Event of l2ToL1Events) {
        const l2ToL1Message = L2ToL1Message.fromEvent(
          parentChainSigner,
          l2ToL1Event
        );
        if (!oneOff) {
          console.log(`Waiting for ${l2ToL1Event.hash} to be ready:`);
          await l2ToL1Message.waitUntilReadyToExecute(
            childChainProvider,
            this.retryDelay
          );
        }

        const status = await l2ToL1Message.status(childChainProvider);
        switch (status) {
          case L2ToL1MessageStatus.CONFIRMED: {
            console.log(l2ToL1Event.hash, "confirmed; executing:");
            const rec = await (
              await l2ToL1Message.execute(childChainProvider)
            ).wait(2);
            console.log(`${l2ToL1Event.hash} executed:`, rec.transactionHash);
            break;
          }
          case L2ToL1MessageStatus.EXECUTED: {
            console.log(`${l2ToL1Event.hash} already executed`);
            break;
          }
          case L2ToL1MessageStatus.UNCONFIRMED: {
            console.log(`${l2ToL1Event.hash} not yet confirmed`);
            break;
          }
          default: {
            throw new Error(`Unhandled L2ToL1MessageStatus case: ${status}`);
          }
        }
      }
    }
  }
}


export type OpChildChainConfig = Chain & {
  contracts: {
    portal: { [x: number]: ChainContract }
    disputeGameFactory: { [x: number]: ChainContract }
  }
}

export class OpChildToParentMessageRedeemer extends ChildToParentMessageRedeemer {
  public readonly childChainViemProvider
  public readonly parentChainViemSigner

  constructor(
    childChainRpc: string,
    parentChainRpc: string,
    parentChainPrivateKey: string,
    childToParentRewardRouterAddr: string,
    blockLag: number,
    startBlock: number = 0,
    public readonly childChainViem: OpChildChainConfig,
    public readonly parentChainViem: Chain,
    retryDelay = 1000 * 60 * 10,
  ) {
    super(
      childChainRpc,
      parentChainRpc,
      parentChainPrivateKey,
      childToParentRewardRouterAddr,
      blockLag,
      startBlock,
      retryDelay
    )

    this.childChainViemProvider = createPublicClient({
      chain: childChainViem,
      transport: http(childChainRpc),
    }).extend(publicActionsL2())

    this.parentChainViemSigner = createWalletClient({
      chain: parentChainViem,
      account: privateKeyToAccount(
        parentChainPrivateKey as `0x${string}`
      ),
      transport: http(parentChainRpc),
    })
      .extend(publicActions)
      .extend(walletActionsL1())
      .extend(publicActionsL1())
  }

  protected async _handleLogs(logs: Log[], oneOff: boolean): Promise<void> {
    if (!oneOff) throw new Error('OpChildToParentMessageRedeemer only supports one-off mode')
    for (const log of logs) {
      const receipt = await this.childChainViemProvider.getTransactionReceipt({
        hash: log.transactionHash as Hex,
      })

      // 'waiting-to-prove'
      // 'ready-to-prove'
      // 'waiting-to-finalize'
      // 'ready-to-finalize'
      // 'finalized'
      let status: GetWithdrawalStatusReturnType;
      try {
        status = await this.parentChainViemSigner.getWithdrawalStatus({
          receipt,
          targetChain: this.childChainViemProvider.chain,
        })
      } catch (e: any) {
        // workaround
        if (e.metaMessages[0] === 'Error: Unproven()') {
          status = 'ready-to-prove'
        }
        else {
          throw e;
        }
      }

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

