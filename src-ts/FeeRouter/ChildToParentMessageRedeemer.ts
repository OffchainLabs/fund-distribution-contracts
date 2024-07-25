import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "ethers";
import { ethers as ethersv6 } from "ethers-v6";
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

import { Database } from 'better-sqlite3';
import { LogCache } from 'fetch-logs-with-cache'

const wait = async (ms: number) => new Promise((res) => setTimeout(res, ms));

export default class ChildToParentMessageRedeemer {
  public readonly childToParentRewardRouter: ChildToParentRewardRouter;

  constructor(
    public readonly db: Database,
    public readonly childChainProvider: JsonRpcProvider,
    public readonly parentChainSigner: Wallet,
    public readonly childToParentRewardRouterAddr: string,
    public readonly startBlock: number,
    public readonly logPageSize: number,
  ) {
    this.childToParentRewardRouter = ChildToParentRewardRouter__factory.connect(
      childToParentRewardRouterAddr,
      childChainProvider
    );
  }

  private _getFundsRoutedLogs() {
    return new LogCache(this.db).getLogs(
      new ethersv6.JsonRpcProvider(this.childChainProvider.connection.url),
      {
        fromBlock: this.startBlock,
        ...this.childToParentRewardRouter.filters.FundsRouted(),
      },
      this.logPageSize
    )
  }

  public async run() {
    const logs = await this._getFundsRoutedLogs();
    if (logs.length) {
      console.log(
        `Found ${logs.length} route events between blocks ${this.startBlock} and latest`
      );
    }

    const l1ToL1Events: EventArgs<L2ToL1TxEvent>[] = [];
    for (let log of logs) {
      const arbTransactionRec = new L2TransactionReceipt(
        await this.childChainProvider.getTransactionReceipt(log.transactionHash)
      );
      l1ToL1Events.push(...arbTransactionRec.getL2ToL1Events() as EventArgs<L2ToL1TxEvent>[])
    }


    for (let l2ToL1Event of l1ToL1Events) {
      const l2ToL1Message = L2ToL1Message.fromEvent(
        this.parentChainSigner,
        l2ToL1Event
      );

      const status = await l2ToL1Message.status(this.childChainProvider);
      switch (status) {
        case L2ToL1MessageStatus.CONFIRMED: {
          console.log(l2ToL1Event.hash, "confirmed; executing:");
          const rec = await (
            await l2ToL1Message.execute(this.childChainProvider)
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
