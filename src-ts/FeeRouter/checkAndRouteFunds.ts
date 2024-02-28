import { Wallet, BigNumber } from "ethers";
import {
  ParentToChildRewardRouter__factory,
  ParentToChildRewardRouter,
} from "../../typechain-types";
import { Inbox__factory } from "../../lib/arbitrum-sdk/src/lib/abi/factories/Inbox__factory";
import { ERC20__factory } from "../../lib/arbitrum-sdk/src/lib/abi/factories/ERC20__factory";

import { L1TransactionReceipt, L1ToL2MessageStatus } from "../../lib/arbitrum-sdk/src";

export const checkAndRouteFunds = async (
  ethOrTokenAddress: string,
  parentChainSigner: Wallet,
  childChainSigner: Wallet,
  parentToChildRewardRouterAddr: string,
  minBalance: BigNumber
) => {
  const isEth = ethOrTokenAddress == "ETH";

  if (
    isEth &&
    (
      await parentChainSigner.provider.getBalance(parentToChildRewardRouterAddr)
    ).lt(minBalance)
  ) {
    return;
  }

  if (
    !isEth &&
    (
      await ERC20__factory.connect(
        ethOrTokenAddress,
        parentChainSigner
      ).balanceOf(parentToChildRewardRouterAddr)
    ).lt(minBalance)
  ) {
    return;
  }

  const parentToChildRewardRouter: ParentToChildRewardRouter =
    ParentToChildRewardRouter__factory.connect(
      parentToChildRewardRouterAddr,
      parentChainSigner
    );

  // check if it's time to trigger
  if (
    !(await parentToChildRewardRouter.canDistribute(
      isEth ? "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE" : ethOrTokenAddress
    ))
  ) {
    return;
  }
  console.log("Calling parent to child router:");

  const inbox = Inbox__factory.connect(
    await parentToChildRewardRouter.inbox(),
    parentChainSigner.provider
  );
  // for ETH, retryable has 0 calldata (simple transfer)
  // For token,  it sens data abi.encode(maxSubmissionCost, bytes("")) (length of 96)
  const dataLength = isEth ? 0 : 96;

  const _submissionFee = await inbox.calculateRetryableSubmissionFee(
    dataLength,
    await parentChainSigner.getGasPrice() // NOTE: I'm not sure why 0 doesn't work here, but it doesn't (on sepolia)
  );
  // add a 20% increase for insurance
  const submissionFee = _submissionFee.mul(120).div(100);

  const currentGasgasPrice = await childChainSigner.getGasPrice();
  const minGasPrice = await parentToChildRewardRouter.minGasPrice();

  const gasPrice = currentGasgasPrice.gt(minGasPrice)
    ? currentGasgasPrice
    : minGasPrice;

  // we use the minimum gas limit set in the contract (we presume it's more than enough)
  const gasLimit = await parentToChildRewardRouter.minGasLimit();

  const value = submissionFee.add(gasPrice.mul(gasLimit));

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
      ).wait(1);
      return rec;
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
      ).wait(1);
      return rec;
    }
  })();

  const l1TxRec = new L1TransactionReceipt(rec);
  const l1ToL2Msgs = await l1TxRec.getL1ToL2Messages(childChainSigner);
  if (l1ToL2Msgs.length != 1) throw new Error("Unexpected messages length");

  const l1ToL2Msg = l1ToL2Msgs[0];
  console.log("Waiting for result:");
  const result = await l1ToL2Msg.waitForStatus();
  if (result.status == L1ToL2MessageStatus.FUNDS_DEPOSITED_ON_L2) {
    console.log("Retryable failed; retrying:");

    const rec = await (await l1ToL2Msg.redeem()).wait();
    console.log("Successfully redeemed:", rec.transactionHash);
  } else if (result.status == L1ToL2MessageStatus.REDEEMED) {
    console.log("Successfully redeemed");
  } else {
    throw new Error("Error: unexpected retryable status");
  }
};
