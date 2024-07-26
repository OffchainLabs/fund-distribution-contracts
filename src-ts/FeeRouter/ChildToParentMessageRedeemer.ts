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

import { LogCache } from 'fetch-logs-with-cache'

export default class ChildToParentMessageRedeemer {
  public readonly childToParentRewardRouter: ChildToParentRewardRouter;

  constructor(
    public readonly dbPath: string,
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

  private async _getL2ToL1Events() {
    const logs = await new LogCache(this.dbPath).getLogs(
      new ethersv6.JsonRpcProvider(this.childChainProvider.connection.url),
      {
        fromBlock: this.startBlock,
        ...this.childToParentRewardRouter.filters.FundsRouted(),
      },
      this.logPageSize
    )

    const l2ToL1Events: EventArgs<L2ToL1TxEvent>[] = [];
    for (let log of logs) {
      const arbTransactionRec = new L2TransactionReceipt(
        await this.childChainProvider.getTransactionReceipt(log.transactionHash)
      );
      const evs = arbTransactionRec.getL2ToL1Events() as EventArgs<L2ToL1TxEvent>[];

      if (evs.length != 1) {
        // TODO: handle multiple events in a single transaction
        // this is not that simple because we need to inspect messages to see if they are bridging tokens to the right place
        throw new Error(`Expected 1 L2ToL1 event, got ${evs.length}`);
      }

      l2ToL1Events.push(...evs);
    }

    return l2ToL1Events
  }

  public async run() {
    const l2ToL1Events = await this._getL2ToL1Events();
    if (l2ToL1Events.length) {
      console.log(
        `Found ${l2ToL1Events.length} route events between blocks ${this.startBlock} and latest`
      );
    }

    for (let l2ToL1Event of l2ToL1Events) {
      const l2ToL1Message = L2ToL1Message.fromEvent(
        this.parentChainSigner,
        l2ToL1Event
      );

      const status = await l2ToL1Message.status(this.childChainProvider);
      const evHash = l2ToL1Event.hash.toHexString();
      switch (status) {
        case L2ToL1MessageStatus.CONFIRMED: {
          console.log(evHash, "confirmed; executing:");
          const rec = await (
            await l2ToL1Message.execute(this.childChainProvider)
          ).wait(2);
          console.log(`${evHash} executed:`, rec.transactionHash);
          break;
        }
        case L2ToL1MessageStatus.EXECUTED: {
          console.log(`${evHash} already executed`);
          break;
        }
        case L2ToL1MessageStatus.UNCONFIRMED: {
          console.log(`${evHash} not yet confirmed`);
          break;
        }
        default: {
          throw new Error(`Unhandled L2ToL1MessageStatus case: ${status}`);
        }
      }
    }
  }
}
