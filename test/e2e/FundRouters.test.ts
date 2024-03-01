import { expect } from "chai";
import { TestSetup, testSetup } from "./testSetup";
import { BigNumber, utils, Wallet } from "ethers";
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
import { Erc20Bridger, RetryableDataTools } from "../../lib/arbitrum-sdk/src";

describe("Router e2e test", () => {
  let setup: TestSetup;
  let parentToChildRewardRouter: ParentToChildRewardRouter;
  let childToParentRewardRouter: ChildToParentRewardRouter;
  let rewardDistributor: RewardDistributor;
  let testToken: TestERC20;
  let l2TokenAddress: string;
  const noTokenAddress = "0x0000000000000000000000000000000000000001";
  const destination = Wallet.createRandom().address;

  before(async () => {
    setup = await testSetup();

    testToken = await new TestERC20__factory().connect(setup.l1Signer).deploy();
    await testToken.deployed();

    await (await testToken.mint()).wait();
    console.log(
      "using L1 wallet:",
      setup.l1Signer.address,
      await setup.l1Signer.getBalance()
    );
    console.log(
      "using L2 wallet:",
      setup.l2Signer.address,
      await setup.l2Signer.getBalance()
    );

    ////////////////////////////////////////////////////////////////

    // Initial token deposit:
    const erc20Bridger = new Erc20Bridger(setup.l2Network);

    console.log("starting deposit");
    // const retryableOverrides = {
    //   maxFeePerGas: {
    //     base: utils.parseUnits("10", "gwei"),
    //   },
    //   gasLimit: {
    //     base: 3000000,
    //   },
    // };
    console.log("depositing:");
    await (await erc20Bridger.approveToken({
      erc20L1Address: testToken.address,
      l1Signer: setup.l1Signer,
    })).wait()
    const depositRes = await erc20Bridger.deposit({
      amount: BigNumber.from(1000),
      erc20L1Address: testToken.address,
      l1Signer: setup.l1Signer,
      l2Provider: setup.l2Provider,
    });
    console.log(depositRes);

    console.log("getting deposit receipt");

    const depositRec = await depositRes.wait();
    console.log(depositRec);

    console.log("waiting for retryables");

    const waitRes = await depositRec.waitForL2(setup.l2Signer);
    l2TokenAddress = await erc20Bridger.getL2ERC20Address(
      testToken.address,
      setup.l1Provider
    );

    ////////////////////////////////////////////////////////////////

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
    ).deploy([childToParentRewardRouter.address], [10000]);
    console.log("Reward Distributor deployed:", rewardDistributor.address);
  });

  it("should have the correct network information", async () => {
    expect(setup.l1Network.chainID).to.eq(1337);
    expect(setup.l2Network.chainID).to.eq(412346);
  });

  describe("e2e eth routing test", async () => {
    const ethValue = utils.parseEther(".23");
    it("destination has initial balance of 0", async () => {
      const initialBal = await setup.l2Provider.getBalance(destination);

      expect(initialBal.toNumber()).to.eq(0);
    });

    // fund reward distributor
    it("funds and pokes reward distributor", async () => {
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
      expect(
        (
          await setup.l2Provider.getBalance(rewardDistributor.address)
        ).toNumber()
      ).to.equal(0);

      expect(
        (
          await setup.l2Provider.getBalance(childToParentRewardRouter.address)
        ).toNumber()
      ).to.equal(0);
    });

    it("redeems l2 to l1 message", async () => {
      await new ChildToParentMessageRedeemer(
        setup.l2Provider,
        setup.l1Signer,
        childToParentRewardRouter.address,
        0,
        0
      ).redeemChildToParentMessages();

      // funds should be in parentToChildRewardRouter now
      expect(
        (
          await setup.l1Provider.getBalance(parentToChildRewardRouter.address)
        ).toHexString()
      ).to.eq(ethValue.toHexString());
    });

    it("routes runds to destination ", async () => {
      await checkAndRouteFunds(
        "ETH",
        setup.l1Signer,
        setup.l2Signer,
        parentToChildRewardRouter.address,
        BigNumber.from(0)
      );
      expect(
        (await setup.l2Provider.getBalance(destination)).toHexString()
      ).to.eq(ethValue.toHexString());
    });
  });
});
