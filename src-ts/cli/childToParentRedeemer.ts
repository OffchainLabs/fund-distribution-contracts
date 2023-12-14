import dotenv from "dotenv";
import yargs from "yargs";
import ChildToParentMessageRedeemer from "../FeeRouter/ChildToParentMessageRedeemer";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "ethers";

dotenv.config();

const PARENT_CHAIN_PK = process.env.PARENT_CHAIN_PK;

if (!PARENT_CHAIN_PK) throw new Error("Need PARENT_CHAIN_PK");

const options = yargs(process.argv.slice(2))
  .options({
    parentRPCUrl: { type: "string", demandOption: true },
    childRPCUrl: { type: "string", demandOption: true },
    childToParentRewardRouterAddr: { type: "string", demandOption: true },
    blockLag: { type: "number", demandOption: false, default: 5 },
    childChainStartBlock: { type: "number", demandOption: false, default: 0 },
    oneOff: {
      type: "boolean",
      demandOption: false,
      default: false,
      description:
        "Runs continuously if false, runs once and terminates if true",
    },
  })
  .parseSync() as {
  parentRPCUrl: string;
  childRPCUrl: string;
  childToParentRewardRouterAddr: string;
  blockLag: number;
  childChainStartBlock: number;
  oneOff: boolean;
};

(async () => {
  const parentChildSigner = new Wallet(
    PARENT_CHAIN_PK,
    new JsonRpcProvider(options.parentRPCUrl)
  );
  console.log(`Signing with ${parentChildSigner.address} on parent chain 
  ${(await parentChildSigner.provider.getNetwork()).chainId}'`);

  const redeemer = new ChildToParentMessageRedeemer(
    new JsonRpcProvider(options.childRPCUrl),
    parentChildSigner,
    options.childToParentRewardRouterAddr,
    options.blockLag,
    options.childChainStartBlock
  );
  await redeemer.run(options.oneOff);
})();
