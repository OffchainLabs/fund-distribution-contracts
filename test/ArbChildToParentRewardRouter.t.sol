// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../src/FeeRouter/ArbChildToParentRewardRouter.sol";
import "./util/TestToken.sol";
import "./util/ChildToParentGatewayRouterMock.sol";
import "./util/ArbSysMock.sol";
import "./Empty.sol";

import "forge-std/Test.sol";

contract TestArbChildToParentRewardRouter is ArbChildToParentRewardRouter {
    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress,
        address _childChainGatewayRouter
    ) ArbChildToParentRewardRouter(
        _parentChainTarget,
        _minDistributionIntervalSeconds,
        _parentChainTokenAddress,
        _childChainTokenAddress,
        _childChainGatewayRouter
    ) {}

    function triggerSendNative(uint256 amount) external {
        _sendNative(amount);
    }

    function triggerSendToken(uint256 amount) external {
        _sendToken(amount);
    }
}

contract ArbChildToParentRewardRouterTest is Test {
    address parentToken = address(0x202020);
    address gateway = address(0x303030);
    address parentTarget = address(0x404040);
    TestToken token;
    address me = address(111_1);
    TestArbChildToParentRewardRouter childToParentRewardRouter;
    ChildToParentGatewayRouterMock gatewayRouter;
    uint256 minDistributionIntervalSeconds = 20;

    function setUp() public {
        vm.etch(address(100), address(new ArbSysMock()).code);
        vm.deal(me, 10 ether);

        vm.prank(me);
        token = new TestToken(100 ether);

        gatewayRouter = new ChildToParentGatewayRouterMock();
        gatewayRouter.setGateway(parentToken, gateway);
        gatewayRouter.setL2TokenAddress(parentToken, address(token));

        childToParentRewardRouter = new TestArbChildToParentRewardRouter(
            parentTarget, minDistributionIntervalSeconds, parentToken, address(token), address(gatewayRouter)
        );

        assertEq(address(childToParentRewardRouter.childChainGatewayRouter()), address(gatewayRouter), "gateway set");
    }

    function testSanityCheck() public {
        vm.etch(address(100), "");
        vm.expectRevert(ArbChildToParentRewardRouter.NotArbitrum.selector);
        new TestArbChildToParentRewardRouter(
            parentTarget, minDistributionIntervalSeconds, parentToken, address(token), address(gatewayRouter)
        );
        vm.etch(address(100), address(new ArbSysMock()).code);

        gatewayRouter.setL2TokenAddress(parentToken, address(0));
        vm.expectRevert(abi.encodeWithSelector(ArbChildToParentRewardRouter.TokenNotRegisteredToGateway.selector, parentToken));
        new TestArbChildToParentRewardRouter(
            parentTarget, minDistributionIntervalSeconds, parentToken, address(token), address(gatewayRouter)
        );
        gatewayRouter.setL2TokenAddress(parentToken, address(token));

        gatewayRouter.setGateway(parentToken, address(0));
        vm.expectRevert(abi.encodeWithSelector(ArbChildToParentRewardRouter.TokenDisabled.selector, parentToken));
        new TestArbChildToParentRewardRouter(
            parentTarget, minDistributionIntervalSeconds, parentToken, address(token), address(gatewayRouter)
        );
    }

    function testSendNative(uint64 amount) external {
        vm.deal(address(childToParentRewardRouter), 2*uint256(amount));
        vm.expectEmit(true, false, false, true, address(100));
        emit ArbSysMock.ArbSysL2ToL1Tx(address(childToParentRewardRouter), parentTarget, amount, "");
        childToParentRewardRouter.triggerSendNative(amount);
    }

    function testSendToken(uint256 amount) external {
        amount = bound(amount, 1, 10 ether);
        vm.prank(me);
        token.transfer(address(childToParentRewardRouter), 2*amount);

        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(address(childToParentRewardRouter), address(gateway), amount + 1);
        vm.expectEmit(true, false, false, true, address(gatewayRouter));
        emit ChildToParentGatewayRouterMock.OutboundTransfer(parentToken, parentTarget, amount, "");
        childToParentRewardRouter.triggerSendToken(amount);
    }
}
