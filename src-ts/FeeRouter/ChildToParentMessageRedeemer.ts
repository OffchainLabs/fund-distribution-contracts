import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "ethers";
import {
  ChildToParentRewardRouter__factory,
  ChildToParentRewardRouter,
} from "../../typechain-types";
import { L2ToL1TxEvent } from "../../lib/arbitrum-sdk/dist/lib/abi/ArbSys";
import { EventArgs } from "../../lib/arbitrum-sdk/dist/lib/dataEntities/event";

import {
  L2TransactionReceipt,
  L2ToL1Message,
  L2ToL1MessageStatus,
} from "../../lib/arbitrum-sdk";
const wait = async (ms: number) => new Promise((res) => setTimeout(res, ms));

export default class ChildToParentMessageRedeemer {
  public startBlock: number;
  public childToParentRewardRouter: ChildToParentRewardRouter;
  constructor(
    public readonly childChainProvider: JsonRpcProvider,
    public readonly parentChainSigner: Wallet,
    public readonly childToParentRewardRouterAddr: string,
    public readonly blockLag: number,
    initialStartBlock: number
  ) {
    this.startBlock = initialStartBlock;
    this.childToParentRewardRouter = ChildToParentRewardRouter__factory.connect(
      childToParentRewardRouterAddr,
      childChainProvider
    );
  }

  public async redeemChildToParentMessages(oneOff = false) {
    const toBlock =
      (await this.childChainProvider.getBlockNumber()) - this.blockLag;
    const logs = await this.childChainProvider.getLogs({
      fromBlock: this.startBlock,
      toBlock: toBlock,
      ...this.childToParentRewardRouter.filters.FundsRouted(),
    });
    if (logs.length) {
      console.log(
        `Found ${logs.length} route events between blocks ${this.startBlock} and ${toBlock}`
      );
    }

    for (let log of logs) {
      const arbTransactionRec = new L2TransactionReceipt(
        await this.childChainProvider.getTransactionReceipt(log.transactionHash)
      );
      const l2ToL1Events = (
        (await arbTransactionRec.getL2ToL1Events()) as EventArgs<L2ToL1TxEvent>[]
      )
        // Filter out any other L2 to L1 messages initiated in this transaction
        .filter(
          (l2ToL1Event) =>
            l2ToL1Event.caller.toLowerCase() ===
            this.childToParentRewardRouter.address.toLowerCase()
        );
      // sanity check
      if (l2ToL1Events.length === 0) {
        throw new Error("Impossible result: L2 to L1 msg not found");
      }

      for (let l2ToL1Event of l2ToL1Events) {
        const l2ToL1Message = L2ToL1Message.fromEvent(
          this.parentChainSigner,
          l2ToL1Event
        );
        if (!oneOff) {
          console.log(`Waiting for ${l2ToL1Event.hash} to be ready:`);
          await l2ToL1Message.waitUntilReadyToExecute(
            this.childChainProvider,
            1000 * 60 * 30
          );
        }

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
    this.startBlock = toBlock;
  }

  public async run(oneOff = false) {
    while (true) {
      try {
        await this.redeemChildToParentMessages(oneOff);
      } catch (err) {
        console.log("err", err);
      }
      if (oneOff) {
        break;
      } else {
        await wait(1000 * 60 * 60);
      }
    }
  }
}
