import { readFileSync } from 'fs'
import { RewardDistributor__factory } from '../../typechain-types'
import { DoubleProvider, DoubleWallet } from '../template/util'
import { RecipientsUpdatedEvent } from '../../typechain-types/src/RewardDistributor'

interface RecipientsAndWeights {
  recipients: string[]
  recipientGroup: string
  weights: number[]
  recipientWeights: string
}
export const getRecipientsAndWeights = async (
  rewardDistAddress: string,
  provider: DoubleProvider,
  fromBlock = 0
): Promise<RecipientsAndWeights> => {
  const distributor = RewardDistributor__factory.connect(
    rewardDistAddress,
    provider
  )

  const logs = await provider.getLogs({
    fromBlock,
    ...distributor.filters.RecipientsUpdated(),
  })
  const latestLog = logs[logs.length - 1]
  if (!latestLog) throw new Error('No updates found')

  const eventObj = distributor.interface.parseLog(latestLog)!
    .args as unknown as RecipientsUpdatedEvent.OutputObject
  return {
    recipients: eventObj.recipients,
    recipientGroup: eventObj.recipientGroup,
    weights: eventObj.weights.map(w => Number(w)),
    recipientWeights: eventObj.recipientWeights,
  }
}

export const distributeRewards = async (
  connectedSigner: DoubleWallet,
  distributorAddr: string,
  _minBalanceWei?: bigint
) => {
  const chainId = await connectedSigner.v5.getChainId()
  const minBalanceWei = _minBalanceWei || 0n
  const distributor = RewardDistributor__factory.connect(
    distributorAddr,
    connectedSigner
  )
  console.log(connectedSigner.address)

  const bal = await connectedSigner.provider.getBalance(distributorAddr)
  if (bal < minBalanceWei) {
    console.log('Balance too low')
    console.log('Min balance', minBalanceWei.toString())
    console.log('Balance', bal.toString())
    return
  }

  const dataBuf = await readFileSync(
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
      connectedSigner.doubleProvider
    )
  }
  const res = await distributor.distributeRewards(
    recAndWeights.recipients,
    recAndWeights.weights
  )
  const rec = (await res.wait())!
  console.log('Rewards distributed', rec.hash)
}
