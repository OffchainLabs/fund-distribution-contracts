import { expect } from "chai";
import { TestSetup, testSetup } from "./testSetup";
import { BigNumber, utils } from "ethers";
import {
  ParentToChildRewardRouter__factory,
  ChildToParentRewardRouter__factory,
  RewardDistributor__factory,
} from "../../typechain-types";
import ChildToParentMessageRedeemer from "../../src-ts/FeeRouter/ChildToParentMessageRedeemer";
import { checkAndRouteFunds } from "../../src-ts/FeeRouter/checkAndRouteFunds";

describe("Router e2e test", () => {
  let setup: TestSetup;

  before(async () => {
    setup = await testSetup();
  });

  it("should have the correct network information", async () => {
    expect(setup.l1Network.chainID).to.eq(1337);
    expect(setup.l2Network.chainID).to.eq(412346);
    expect(setup.l3Network.chainID).to.eq(333333);
  });

  it("e2e eth routing test", async () => {
    const destination = "0x0000000000000000000000000000000000000002";
    const initialBal = await setup.l2Provider.getBalance(destination);
    expect(initialBal.eq(0)).to.be.true;

    // deploy parent to child
    const parentToChildRewardRouter =
      await new ParentToChildRewardRouter__factory(setup.l1Signer).deploy(
        setup.l2Network.tokenBridge.l1GatewayRouter,
        destination,
        10,
        utils.formatUnits(0.1, "gwei"),
        300000
      );

    // deploy child to parent
    const childToParentRewardRouter =
      await new ChildToParentRewardRouter__factory(setup.l2Signer).deploy(
        parentToChildRewardRouter.address,
        10,
        "0x0000000000000000000000000000000000000001",
        "0x0000000000000000000000000000000000000001",
        "0x0000000000000000000000000000000000000001"
      );

    // deploy fund distributor
    const rewardDistributor = await new RewardDistributor__factory(
      setup.l2Signer
    ).deploy([childToParentRewardRouter.address], [1000]);

    const value = utils.parseEther(".23");

    // fund reward distributor
    const sendRec = await (
      await setup.l2Signer.sendTransaction({
        value: value,
        to: rewardDistributor.address,
      })
    ).wait();

    // poke reward distributor
    const distributeRec = await (
      await rewardDistributor.distributeRewards(
        [childToParentRewardRouter.address],
        [1000]
      )
    ).wait();

    // fund should be distributed and auto-routed
    expect((await setup.l2Provider.getBalance(rewardDistributor.address)).eq(0))
      .to.be.true;

    expect(
      (await setup.l2Provider.getBalance(childToParentRewardRouter.address)).eq(
        0
      )
    ).to.be.true;

    await new ChildToParentMessageRedeemer(
      setup.l2Provider,
      setup.l1Signer,
      childToParentRewardRouter.address,
      0,
      0
    ).redeemChildToParentMessages();

    // funds should be in parentToChildRewardRouter now
    expect(
      (await setup.l1Provider.getBalance(parentToChildRewardRouter.address)).eq(
        value
      )
    ).to.be.true;

    await checkAndRouteFunds(
      "ETH",
      setup.l1Signer,
      setup.l2Signer,
      parentToChildRewardRouter.address,
      BigNumber.from(0)
    );
    expect((await setup.l1Provider.getBalance(destination)).eq(value)).to.be
      .true;
  });
});
