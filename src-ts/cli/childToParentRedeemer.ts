import dotenv from "dotenv";
import yargs from "yargs";
import ChildToParentMessageRedeemer from "../FeeRouter/ChildToParentMessageRedeemer";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "ethers";
import Database from "better-sqlite3";

dotenv.config();

const PARENT_CHAIN_PK = process.env.PARENT_CHAIN_PK;

if (!PARENT_CHAIN_PK) throw new Error("Need PARENT_CHAIN_PK");

const options = yargs(process.argv.slice(2))
  .options({
    dbPath: { type: "string", demandOption: true },
    parentRPCUrl: { type: "string", demandOption: true },
    childRPCUrl: { type: "string", demandOption: true },
    childToParentRewardRouterAddr: { type: "string", demandOption: true },
    childChainStartBlock: { type: "number", demandOption: false, default: 0 },
    logPageSize: { type: "number", demandOption: false, default: 1000 },
  })
  .parseSync();

(async () => {
  const parentChildSigner = new Wallet(
    PARENT_CHAIN_PK,
    new JsonRpcProvider(options.parentRPCUrl)
  );
  console.log(`Signing with ${parentChildSigner.address} on parent chain 
  ${(await parentChildSigner.provider.getNetwork()).chainId}'`);

  const redeemer = new ChildToParentMessageRedeemer(
    new Database(options.dbPath),
    new JsonRpcProvider(options.childRPCUrl),
    parentChildSigner,
    options.childToParentRewardRouterAddr,
    options.childChainStartBlock,
    options.logPageSize
  );
  await redeemer.run();
})();
