import { parseEther, Provider, Wallet } from 'ethers'
import { RewardDistributor__factory } from '../../typechain-types'

import { readFileSync } from 'fs'
import { RecipientsUpdatedEvent } from '../../typechain-types/contracts/RewardDistributor'

interface RecipientsAndWeights {
  recipients: string[]
  recipientGroup: string
  weights: number[]
  recipientWeights: string
}
export const getRecipientsAndWeights = async (
  rewardDistAddress: string,
  provider: Provider,
  fromBlock = 0
): Promise<RecipientsAndWeights> => {
  const distributor = RewardDistributor__factory.connect(
    rewardDistAddress,
    provider
  )

  const logs = await provider.getLogs({
    fromBlock,
    address: distributor.getAddress(),
    topics: [distributor.interface.getEvent('RecipientsUpdated').topicHash],
  })
  const latestLog = logs[logs.length - 1] as
    | RecipientsUpdatedEvent.Log
    | undefined
  if (!latestLog) throw new Error('No updates found')

  return {
    recipients: latestLog.args.recipients,
    recipientGroup: latestLog.args.recipientGroup,
    weights: latestLog.args.weights.map((w: bigint) => parseInt(w.toString())),
    recipientWeights: latestLog.args.recipientWeights,
  }
}

export const distributeRewards = async (
  connectedSigner: Wallet,
  distributorAddr: string,
  _minBalanceEther?: number
) => {
  const chainId = (await connectedSigner.provider!.getNetwork()).chainId
  const minBalanceWei = _minBalanceEther
    ? parseEther(_minBalanceEther.toString())
    : 0n
  const distributor = RewardDistributor__factory.connect(
    distributorAddr,
    connectedSigner
  )
  console.log(connectedSigner.address)

  const bal = await connectedSigner.provider!.getBalance(distributorAddr)
  if (bal < minBalanceWei) {
    console.log('Balance too low')
    console.log('Min balance', minBalanceWei.toString())
    console.log('Balance', bal.toString())
    return
  }

  const dataBuf = readFileSync(
    './src-ts/data/recipientAndWeightsData.json'
  ).toString()
  const data = JSON.parse(dataBuf).data

  let recAndWeights = data.find(
    (datum: any) =>
      datum.chainId === chainId &&
      datum.address.toLowerCase() === distributorAddr.toLowerCase()
  ) as RecipientsAndWeights

  if (!recAndWeights) {
    recAndWeights = await getRecipientsAndWeights(
      distributorAddr,
      connectedSigner.provider!
    )
  }
  const res = await distributor.distributeRewards(
    recAndWeights.recipients,
    recAndWeights.weights
  )
  const rec = await res.wait()
  console.log('Rewards distributed', rec!.hash)
}
