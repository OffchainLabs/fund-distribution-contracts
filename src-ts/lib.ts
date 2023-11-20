import { RewardDistributor__factory } from "../typechain-types";
import { RecipientsUpdatedEventObject } from "../typechain-types/src/RewardDistributor";

import { JsonRpcProvider } from "@ethersproject/providers";
import { rewardDistributors } from "./daoRewardDistributorContracts"

export const getRecipientsAndWeights = async (
  rewardDistAddress: string,
  provider: JsonRpcProvider,
  fromBlock = 0
) => {
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

  const eventObj =  distributor.interface.parseLog(latestLog)
    .args as unknown as RecipientsUpdatedEventObject;

    return {
      recipients: eventObj.recipients,
      recipientGroup: eventObj.recipientGroup,
      weights: eventObj.weights.map((w)=> w.toNumber()),
      recipientWeights: eventObj.recipientWeights
    }
};



