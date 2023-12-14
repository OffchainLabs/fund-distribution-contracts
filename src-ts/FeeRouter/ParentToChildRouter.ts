import { Wallet, BigNumber } from "ethers";
import {
  ParentToChildRewardRouter__factory,
  ParentToChildRewardRouter,
} from "../../typechain-types";
import { Inbox__factory } from "@arbitrum/sdk/dist/lib/abi/factories/Inbox__factory";
import {
  L1TransactionReceipt,
  L1ToL2MessageStatus,
} from "@arbitrum/sdk";

export const checkAndRouteFunds = async (
  parentChainSigner: Wallet,
  childChainSigner: Wallet,
  parentToChildRewardRouterAddr: string,
  minBalance: BigNumber
) => {
  if (
    (await parentChainSigner.provider.getBalance(parentToChildRewardRouterAddr)).lt(
      minBalance
    )
  ) {
    return;
  }

  const parentToChildRewardRouter: ParentToChildRewardRouter =
    ParentToChildRewardRouter__factory.connect(
      parentToChildRewardRouterAddr,
      parentChainSigner
    );

  // check if it's time to trigger 
  if (!(await parentToChildRewardRouter.canDistribute())) {
    return;
  }
  console.log("Calling parent to child router:");
  
  const inbox = Inbox__factory.connect(
    await parentToChildRewardRouter.inbox(),
    parentChainSigner.provider
  );
  // retryable has 0 calldata (simple transfer). 0 in second paramt uses current L1 basefee 
  const _submissionFee = await inbox.calculateRetryableSubmissionFee(0, 0);

  // add a 10% increase for insurance
  const submissionFee = _submissionFee.add(_submissionFee.mul(.1))

  const gasPrice = await childChainSigner.getGasPrice();

  // we use the minimum gas limit set in the contract (we presume it's more than enough)
  const gasLimit = await parentToChildRewardRouter.minGasLimit();

  const value = submissionFee.add(gasPrice.mul(gasLimit));

  const rec = await (
    await parentToChildRewardRouter.routeFunds(
      submissionFee,
      gasLimit,
      gasPrice,
      {
        value,
      }
    )
  ).wait(1);
  console.log('Retryable created', rec.transactionHash);

  const l1TxRec = new L1TransactionReceipt(rec);
  const l1ToL2Msgs = await l1TxRec.getL1ToL2Messages(childChainSigner);
  if (l1ToL2Msgs.length != 1) throw new Error("Unexpected messages length");

  const l1ToL2Msg = l1ToL2Msgs[0]
  console.log('Waiting for result:');
  const result = await l1ToL2Msg.waitForStatus()
  if(result.status == L1ToL2MessageStatus.FUNDS_DEPOSITED_ON_L2 ){
    console.log('Retryable failed; retrying:');
    
    const rec  = await (await l1ToL2Msg.redeem()).wait()
    console.log('Successfully redeemed:', rec.transactionHash);
    
  } else if (result.status == L1ToL2MessageStatus.REDEEMED){
    console.log('Successfully redeemed');
    
  } else {
    throw new Error("Error: unexpected retryable status")
  }
  

};
