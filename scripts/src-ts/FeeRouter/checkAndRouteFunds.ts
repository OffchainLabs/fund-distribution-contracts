import {
  ParentToChildRewardRouter__factory,
  ParentToChildRewardRouter,
  IERC20__factory,
  IInbox__factory,
} from '../../../typechain-types'

import {
  L1TransactionReceipt,
  L1ToL2MessageStatus,
} from '../../../lib/arbitrum-sdk/src'
import { DoubleWallet } from '../../template/util'

export const checkAndRouteFunds = async (
  ethOrTokenAddress: string,
  parentChainSigner: DoubleWallet,
  childChainSigner: DoubleWallet,
  parentToChildRewardRouterAddr: string,
  minBalance: bigint
) => {
  const isEth = ethOrTokenAddress == 'ETH'

  if (
    isEth &&
    (await parentChainSigner.provider.getBalance(
      parentToChildRewardRouterAddr
    )) < minBalance
  ) {
    return
  }

  if (
    !isEth &&
    (await IERC20__factory.connect(
      ethOrTokenAddress,
      parentChainSigner
    ).balanceOf(parentToChildRewardRouterAddr)) < minBalance
  ) {
    return
  }

  const parentToChildRewardRouter: ParentToChildRewardRouter =
    ParentToChildRewardRouter__factory.connect(
      parentToChildRewardRouterAddr,
      parentChainSigner
    )

  // check if it's time to trigger
  if (
    !(await parentToChildRewardRouter.canDistribute(
      isEth ? '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' : ethOrTokenAddress
    ))
  ) {
    return
  }
  console.log('Calling parent to child router:')

  const inbox = IInbox__factory.connect(
    await parentToChildRewardRouter.inbox(),
    parentChainSigner.provider
  )
  // for ETH, retryable has 0 calldata (simple transfer)
  // For token,  it sens data abi.encode(maxSubmissionCost, bytes("")) (length of 96)
  const dataLength = isEth ? 0 : 96

  const parentGasPrice = (await parentChainSigner.provider.getFeeData())
    .gasPrice
  if (parentGasPrice === null) {
    throw new Error('Parent gas price is null')
  }

  const _submissionFee = await inbox.calculateRetryableSubmissionFee(
    dataLength,
    parentGasPrice // NOTE: I'm not sure why 0 doesn't work here, but it doesn't (on sepolia)
  )
  // add a 20% increase for insurance
  const submissionFee = (_submissionFee * 120n) / 100n

  const childGasPrice = (await childChainSigner.provider.getFeeData()).gasPrice
  if (childGasPrice === null) {
    throw new Error('Child gas price is null')
  }
  const minGasPrice = await parentToChildRewardRouter.minGasPrice()

  const gasPrice = childGasPrice > minGasPrice ? childGasPrice : minGasPrice

  // we use the minimum gas limit set in the contract (we presume it's more than enough)
  const gasLimit = await parentToChildRewardRouter.minGasLimit()

  const value = submissionFee + gasPrice * gasLimit

  const rec = await (async () => {
    if (isEth) {
      const rec = await (
        await parentToChildRewardRouter.routeNativeFunds(
          submissionFee,
          gasLimit,
          gasPrice,
          {
            value,
          }
        )
      ).wait(1)
      return rec
    } else {
      const rec = await (
        await parentToChildRewardRouter.routeToken(
          ethOrTokenAddress,
          submissionFee,
          gasLimit,
          gasPrice,
          {
            value,
          }
        )
      ).wait()
      return rec
    }
  })()

  const l1TxRec = new L1TransactionReceipt(
    await parentChainSigner.v5.provider.getTransactionReceipt(rec!.hash)
  )
  const l1ToL2Msgs = await l1TxRec.getL1ToL2Messages(childChainSigner.v5)
  if (l1ToL2Msgs.length != 1) throw new Error('Unexpected messages length')

  const l1ToL2Msg = l1ToL2Msgs[0]
  console.log('Waiting for result:')
  const result = await l1ToL2Msg.waitForStatus()
  if (result.status == L1ToL2MessageStatus.FUNDS_DEPOSITED_ON_L2) {
    console.log('Retryable failed; retrying:')

    const rec = await (await l1ToL2Msg.redeem()).wait()
    console.log('Successfully redeemed:', rec.transactionHash)
  } else if (result.status == L1ToL2MessageStatus.REDEEMED) {
    console.log('Successfully redeemed')
  } else {
    throw new Error('Error: unexpected retryable status')
  }
}
