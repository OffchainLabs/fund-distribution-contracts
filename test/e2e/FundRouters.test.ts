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
  ArbChildToParentRewardRouter__factory,
} from "../../typechain-types";
import { ArbChildToParentMessageRedeemer } from "../../src-ts/FeeRouter/ChildToParentMessageRedeemer";
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
  let l2TestToken: TestERC20;
  const destination = Wallet.createRandom().address;

  console.log("destination", destination);

  before(async () => {
    setup = await testSetup();
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

    testToken = await new TestERC20__factory().connect(setup.l1Signer).deploy();
    await testToken.deployed();
    console.log("Test token L1 deployed", testToken.address);

    await (await testToken.mint()).wait();

    // Initial token deposit:
    const erc20Bridger = new Erc20Bridger(setup.l2Network);

    await (
      await erc20Bridger.approveToken({
        erc20L1Address: testToken.address,
        l1Signer: setup.l1Signer,
      })
    ).wait();
    const depositRes = await erc20Bridger.deposit({
      amount: BigNumber.from(1000),
      erc20L1Address: testToken.address,
      l1Signer: setup.l1Signer,
      l2Provider: setup.l2Provider,
    });

    const depositRec = await depositRes.wait();

    console.log("waiting for retryables");

    await depositRec.waitForL2(setup.l2Signer);
    const l2TokenAddress = await erc20Bridger.getL2ERC20Address(
      testToken.address,
      setup.l1Provider
    );

    console.log("L2 test token:", l2TokenAddress);

    l2TestToken = TestERC20__factory.connect(l2TokenAddress, setup.l2Signer);

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

    console.log("Deploying childToParentRewardRouter:");

    // deploy child to parent
    childToParentRewardRouter = await new ArbChildToParentRewardRouter__factory(
      setup.l2Signer
    ).deploy(
      parentToChildRewardRouter.address,
      10,
      testToken.address,
      l2TokenAddress,
      setup.l2Network.tokenBridge.l2GatewayRouter
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
      await (
        await setup.l2Signer.sendTransaction({
          value: ethValue,
          to: rewardDistributor.address,
        })
      ).wait();

      // poke reward distributor
      await (
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
      await new ArbChildToParentMessageRedeemer(
        setup.l2Provider,
        setup.l1Signer,
        childToParentRewardRouter.address,
        0,
        0,
        1000
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

  describe("token routing test", async () => {
    const tokenValue = BigNumber.from(231);
    it("destination has initial balance of 0", async () => {
      const initialBal = await l2TestToken.balanceOf(destination);

      expect(initialBal.toNumber()).to.eq(0);
    });

    it("funds and pokes child to parent router", async () => {
      await l2TestToken.transfer(childToParentRewardRouter.address, tokenValue);

      // prePokeBlock = setup.l2
      await (await childToParentRewardRouter.routeToken()).wait();
      expect(
        (
          await l2TestToken.balanceOf(childToParentRewardRouter.address)
        ).toNumber()
      ).to.eq(0);
    });

    it("redeems l2 to l1 message", async () => {
      await new ArbChildToParentMessageRedeemer(
        setup.l2Provider,
        setup.l1Signer,
        childToParentRewardRouter.address,
        0,
        0,
        1000
      ).redeemChildToParentMessages();

      // funds should be in parentToChildRewardRouter now
      expect(
        (
          await testToken.balanceOf(parentToChildRewardRouter.address)
        ).toHexString()
      ).to.eq(tokenValue.toHexString());
    });

    it("routes runds to destination ", async () => {
      await checkAndRouteFunds(
        testToken.address,
        setup.l1Signer,
        setup.l2Signer,
        parentToChildRewardRouter.address,
        BigNumber.from(0)
      );
      // funds should be in destination
      expect((await l2TestToken.balanceOf(destination)).toHexString()).to.eq(
        tokenValue.toHexString()
      );
    });
  });
});
