import dotenv from "dotenv";
import yargs from "yargs";
import { JsonRpcProvider } from "@ethersproject/providers";
import { Wallet } from "ethers";
import { distributeRewards } from "../lib";
dotenv.config();

const CHILD_CHAIN_PK = process.env.CHILD_CHAIN_PK;

if (!CHILD_CHAIN_PK) throw new Error("Need CHILD_CHAIN_PK");

const options = yargs(process.argv.slice(2))
  .options({
    rpcURL: { type: "string", demandOption: true },
    rewardDistAddr: { type: "string", demandOption: true },
    minBalanceEther: { type: "number", demandOption: false, default: 0 },
  })
  .parseSync() as {
  rpcURL: string;
  rewardDistAddr: string;
  minBalanceEther: number;
};

(async () => {
  await distributeRewards(
    new Wallet(CHILD_CHAIN_PK, new JsonRpcProvider(options.rpcURL)),
    options.rewardDistAddr,
    options.minBalanceEther
  );
})();
