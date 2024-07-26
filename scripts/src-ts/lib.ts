import { RewardDistributor__factory } from "../typechain-types";
import { RecipientsUpdatedEventObject } from "../typechain-types/src/RewardDistributor";

import { Provider } from "@ethersproject/providers";
import { Wallet, BigNumber, utils } from "ethers";
import { readFileSync } from "fs";

interface RecipientsAndWeights {
  recipients: string[];
  recipientGroup: string;
  weights: number[];
  recipientWeights: string;
}
export const getRecipientsAndWeights = async (
  rewardDistAddress: string,
  provider: Provider,
  fromBlock = 0
): Promise<RecipientsAndWeights> => {
  const distributor = RewardDistributor__factory.connect(
    rewardDistAddress,
    provider
  );

  const logs = await provider.getLogs({
    fromBlock,
    ...distributor.filters.RecipientsUpdated(),
  });
  const latestLog = logs[logs.length - 1];
  if (!latestLog) throw new Error("No updates found");

  const eventObj = distributor.interface.parseLog(latestLog)
    .args as unknown as RecipientsUpdatedEventObject;

  return {
    recipients: eventObj.recipients,
    recipientGroup: eventObj.recipientGroup,
    weights: eventObj.weights.map((w) => w.toNumber()),
    recipientWeights: eventObj.recipientWeights,
  };
};

export const distributeRewards = async (
  connectedSigner: Wallet,
  distributorAddr: string,
  _minBalanceEther?: number
) => {
  const chainId = await connectedSigner.getChainId();
  const minBalanceWei = _minBalanceEther
    ? utils.parseEther(_minBalanceEther.toString())
    : BigNumber.from(0);
  const distributor = RewardDistributor__factory.connect(
    distributorAddr,
    connectedSigner
  );
  console.log(connectedSigner.address);

  const bal = await connectedSigner.provider.getBalance(distributorAddr);
  if (bal.lt(minBalanceWei)) {
    console.log("Balance too low");
    console.log("Min balance", minBalanceWei.toString());
    console.log("Balance", bal.toString());
    return;
  }

  const dataBuf = await readFileSync(
    "./src-ts/data/recipientAndWeightsData.json"
  ).toString();
  const data = JSON.parse(dataBuf).data;

  let recAndWeights = data.find(
    (datum: any) =>
      datum.chainId === chainId &&
      datum.address.toLowerCase() === distributorAddr.toLowerCase()
  ) as RecipientsAndWeights;

  if (!recAndWeights) {
    recAndWeights = await getRecipientsAndWeights(
      distributorAddr,
      connectedSigner.provider
    );
  }
  const res = await distributor.distributeRewards(
    recAndWeights.recipients,
    recAndWeights.weights
  );
  const rec = await res.wait();
  console.log("Rewards distributed", rec.transactionHash);
};
