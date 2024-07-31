import { getRecipientsAndWeights } from "./lib";
import { rewardDistributors, chainID } from "./daoRewardDistributorContracts";
import fs from "fs";
import { RewardDistributor__factory } from "../../typechain-types";

const main = async () => {
  const recAndWeightsJsonData = [];
  const time = new Date().toTimeString();
  for (let { address, chain, feeType } of rewardDistributors) {
    const recAndWeightData = await getRecipientsAndWeights(
      address,
      chain.provider,
      chain.startBlock
    );
    // sanity check
    const distributor = RewardDistributor__factory.connect(
      address,
      chain.provider
    );
    if (
      (await distributor.currentRecipientGroup()) !=
      recAndWeightData.recipientGroup
    ) {
      throw new Error("Recipient group mismatch");
    }

    if (
      (await distributor.currentRecipientWeights()) !=
      recAndWeightData.recipientWeights
    ) {
      throw new Error("Recipient weights mismatch");
    }
    recAndWeightsJsonData.push({
      chain: chain.name,
      chainId: chain.id,
      feeType: feeType,
      address,
      ...recAndWeightData,
    });
  }
  const path = `${process.cwd()}/src-ts/data/recipientAndWeightsData.json`;
  fs.writeFileSync(
    path,
    JSON.stringify({
      updatedAt: time,
      data: recAndWeightsJsonData,
    })
  );
  console.log(`Recipeint and weight data saved to ${path}`);
  
};

main().then(() => console.log("done"));
