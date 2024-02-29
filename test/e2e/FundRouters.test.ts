import { expect } from "chai";
import { TestSetup, testSetup } from "./testSetup";
import { BigNumber, utils } from "ethers";
import {
  ParentToChildRewardRouter__factory,
  ParentToChildRewardRouter,
  ChildToParentRewardRouter__factory,
  ChildToParentRewardRouter,
  RewardDistributor__factory,
  RewardDistributor,
} from "../../typechain-types";
import ChildToParentMessageRedeemer from "../../src-ts/FeeRouter/ChildToParentMessageRedeemer";
import { checkAndRouteFunds } from "../../src-ts/FeeRouter/checkAndRouteFunds";
import { TestERC20__factory } from "../../lib/arbitrum-sdk/src/lib/abi/factories/TestERC20__factory";
import { TestERC20 } from "../../lib/arbitrum-sdk/src/lib/abi/TestERC20";
import { Erc20Bridger } from "../../lib/arbitrum-sdk/src";

describe("Router e2e test", () => {
  let setup: TestSetup;
  let parentToChildRewardRouter: ParentToChildRewardRouter;
  let childToParentRewardRouter: ChildToParentRewardRouter;
  let rewardDistributor: RewardDistributor;
  let testToken: TestERC20;
  let l2TokenAddress: string;
  const noTokenAddress = "0x0000000000000000000000000000000000000001";
  const destination = "0x0000000000000000000000000000000000000002";

  before(async () => {
    setup = await testSetup();

    // testToken = await new TestERC20__factory().connect(setup.l1Signer).deploy();
    // await testToken.deployed();

    // await (await testToken.mint()).wait();
    console.log(
      "using L1 wallet",
      setup.l1Signer.address,
      await setup.l1Signer.getBalance()
    );
    console.log(
      "using L2 wallet",
      setup.l2Signer.address,
      await setup.l2Signer.getBalance()
    );

    // const erc20Bridger = new Erc20Bridger(setup.l2Network);
    // const depositRes = await erc20Bridger.deposit({
    //   l1Signer: setup.l1Signer,
    //   amount: BigNumber.from(1000),
    //   l2Provider: setup.l2Provider,

    //   erc20L1Address: testToken.address,
    // });
    // const depositRec = await depositRes.wait();
    // const waitRes = await depositRec.waitForL2(setup.l2Signer);

    // l2TokenAddress = await erc20Bridger.getL2ERC20Address(
    //   testToken.address,
    //   setup.l1Provider
    // );

    // deploy parent to child
    console.log("Deploying parentToChildRewardRouter:");

    parentToChildRewardRouter = await new ParentToChildRewardRouter__factory(
      setup.l1Signer
    ).deploy(
      setup.l2Network.tokenBridge.l1GatewayRouter,
      destination,
      10,
      100000000,
      300000
    );
    console.log(
      "ParentToChildRewardRouter deployed",
      parentToChildRewardRouter.address
    );

    // // deploy child to parent
    // childToParentRewardRouter = await new ChildToParentRewardRouter__factory(
    //   setup.l2Signer
    // ).deploy(
    //   parentToChildRewardRouter.address,
    //   10,
    //   testToken.address,
    //   l2TokenAddress,
    //   setup.l2Network.tokenBridge.l2GatewayRouter
    // );
    console.log("Deploying childToParentRewardRouter:");

    childToParentRewardRouter = await new ChildToParentRewardRouter__factory(
      setup.l2Signer
    ).deploy(
      parentToChildRewardRouter.address,
      10,
      noTokenAddress,
      noTokenAddress,
      noTokenAddress
    );
    console.log(
      "childToParentRewardRouter deployed:",
      childToParentRewardRouter.address
    );

    // deploy fund distributor
    console.log("Deploying rewardDistributor:");

    rewardDistributor = await new RewardDistributor__factory(
      setup.l2Signer
    ).deploy([childToParentRewardRouter.address], [1000]);
    console.log("Reward Distributor deployed:", rewardDistributor.address);
  });

  it("should have the correct network information", async () => {
    expect(setup.l1Network.chainID).to.eq(1337);
    expect(setup.l2Network.chainID).to.eq(412346);
    expect(setup.l3Network.chainID).to.eq(333333);
  });

  it("e2e eth routing test", async () => {
    const initialBal = await setup.l2Provider.getBalance(destination);
    expect(initialBal.eq(0)).to.be.true;

    const ethValue = utils.parseEther(".23");
    // fund reward distributor
    const sendRec = await (
      await setup.l2Signer.sendTransaction({
        value: ethValue,
        to: rewardDistributor.address,
      })
    ).wait();

    // poke reward distributor
    const distributeRec = await (
      await rewardDistributor.distributeRewards(
        [childToParentRewardRouter.address],
        [10000]
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
        ethValue
      )
    ).to.be.true;

    await checkAndRouteFunds(
      "ETH",
      setup.l1Signer,
      setup.l2Signer,
      parentToChildRewardRouter.address,
      BigNumber.from(0)
    );
    expect((await setup.l1Provider.getBalance(destination)).eq(ethValue)).to.be
      .true;
  });
});
