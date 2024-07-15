// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../src/FeeRouter/ArbChildToParentRewardRouter.sol";
import "./util/TestToken.sol";
import "./Empty.sol";

import "forge-std/Test.sol";

contract TestChildToParentRewardRouter is ChildToParentRewardRouter {
    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress
    )
        ChildToParentRewardRouter(
            _parentChainTarget,
            _minDistributionIntervalSeconds,
            _parentChainTokenAddress,
            _childChainTokenAddress
        )
    {}

    function _sendNative(uint256 amount) internal override {
        (bool b,) = address(parentChainTarget).call{value: amount}("");
        require(b, "send failed");
    }

    function _sendToken(uint256 amount) internal override {
        IERC20(childChainTokenAddress).transfer(parentChainTarget, amount);
    }
}

contract ChildToParentRewardRouterTest is Test {
    address parentToken = address(0x202020);
    TestToken token;
    address me = address(111_1);
    TestChildToParentRewardRouter childToParentRewardRouter;
    TestChildToParentRewardRouter nativeOnlyChildToParentRewardRouter;
    uint256 minDistributionIntervalSeconds = 20;

    function setUp() public {
        vm.deal(me, 10 ether);

        vm.prank(me);
        token = new TestToken(100 ether);

        childToParentRewardRouter = new TestChildToParentRewardRouter(
            address(1111_2), minDistributionIntervalSeconds, parentToken, address(token)
        );
        nativeOnlyChildToParentRewardRouter =
            new TestChildToParentRewardRouter(address(1111_3), minDistributionIntervalSeconds, address(1), address(1));
    }

    function testZeroAddressConstructorCheck() public {
        vm.expectRevert(abi.encodeWithSelector(ChildToParentRewardRouter.ZeroAddress.selector));
        new TestChildToParentRewardRouter(address(0), minDistributionIntervalSeconds, parentToken, address(token));
        vm.expectRevert(abi.encodeWithSelector(ChildToParentRewardRouter.ZeroAddress.selector));
        new TestChildToParentRewardRouter(address(1111_2), minDistributionIntervalSeconds, address(0), address(token));
        vm.expectRevert(abi.encodeWithSelector(ChildToParentRewardRouter.ZeroAddress.selector));
        new TestChildToParentRewardRouter(address(1111_2), minDistributionIntervalSeconds, parentToken, address(0));
    }

    function testRouteNativeFunds() external {
        vm.startPrank(address(me));
        (bool sent,) = payable(address(childToParentRewardRouter)).call{value: 1 ether}("");
        assertTrue(sent, "funds sent");
        assertEq(address(childToParentRewardRouter).balance, 0, "funds routed");
        assertEq(address(1111_2).balance, 1 ether, "funds received");
        vm.stopPrank();
    }

    function testRouteToken() external {
        vm.startPrank(me);
        token.transfer(address(childToParentRewardRouter), 10 ether);
        childToParentRewardRouter.routeToken();
        assertEq(token.balanceOf(address(childToParentRewardRouter)), 0, "funds routed");
        assertEq(token.balanceOf(address(1111_2)), 10 ether, "funds received");
        vm.stopPrank();
    }

    function testCantrouteNativeFundsTooSoon() external {
        vm.startPrank(me);
        (bool sent,) = address(childToParentRewardRouter).call{value: 1 ether}("");
        assertTrue(sent, "funds sent");
        (sent,) = address(childToParentRewardRouter).call{value: 1 ether}("");
        assertTrue(sent, "funds sent");
        assertEq(address(childToParentRewardRouter).balance, 1 ether, "funds routed only once");

        childToParentRewardRouter.routeNativeFunds();
        assertEq(address(childToParentRewardRouter).balance, 1 ether, "funds still routed only once");
        vm.warp(block.timestamp + minDistributionIntervalSeconds);
        childToParentRewardRouter.routeNativeFunds();

        assertEq(address(childToParentRewardRouter).balance, 0, "funds routed after warp");
        vm.stopPrank();
    }

    function testCantRouteTokenTooSoon() external {
        vm.startPrank(me);
        token.transfer(address(childToParentRewardRouter), 1 ether);
        childToParentRewardRouter.routeToken();
        token.transfer(address(childToParentRewardRouter), 1 ether);
        childToParentRewardRouter.routeToken();
        assertEq(token.balanceOf(address(childToParentRewardRouter)), 1 ether, "funds routed only once");

        childToParentRewardRouter.routeToken();
        assertEq(token.balanceOf(address(childToParentRewardRouter)), 1 ether, "funds still routed only once");
        vm.warp(block.timestamp + minDistributionIntervalSeconds);
        childToParentRewardRouter.routeToken();

        assertEq(token.balanceOf(address(childToParentRewardRouter)), 0, "funds routed after warp");
        vm.stopPrank();
    }

    function testCantRouteTokensWhenSetToNativeOnly() external {
        vm.expectRevert(abi.encodeWithSelector(ChildToParentRewardRouter.NativeOnly.selector));
        nativeOnlyChildToParentRewardRouter.routeToken();
    }

    function testDistributionUpdate() external {
        address native = childToParentRewardRouter.NATIVE_CURRENCY();
        _assertDistribution(parentToken, 0, true, 0);
        _assertDistribution(native, 0, true, 0);

        // route 0 native funds
        childToParentRewardRouter.routeNativeFunds();
        _assertDistribution(parentToken, 0, true, 0);
        _assertDistribution(native, 0, true, 0);

        // route 0 token funds
        childToParentRewardRouter.routeToken();
        _assertDistribution(parentToken, 0, true, 0);
        _assertDistribution(native, 0, true, 0);

        // route some native
        vm.prank(me);
        (bool sent,) = payable(address(childToParentRewardRouter)).call{value: 1 ether}("");
        assertTrue(sent, "funds sent");
        _assertDistribution(parentToken, 0, true, 0);
        _assertDistribution(
            native, minDistributionIntervalSeconds, false, block.timestamp + minDistributionIntervalSeconds
        );

        // warp
        vm.warp(block.timestamp + 2 * minDistributionIntervalSeconds);

        // route some token
        vm.prank(me);
        token.transfer(address(childToParentRewardRouter), 1 ether);
        childToParentRewardRouter.routeToken();
        _assertDistribution(
            parentToken, minDistributionIntervalSeconds, false, block.timestamp + minDistributionIntervalSeconds
        );
        _assertDistribution(native, 0, true, block.timestamp - minDistributionIntervalSeconds);
    }

    function _assertDistribution(address addr, uint256 timeToNext, bool canDistribute, uint256 next) internal {
        assertEq(childToParentRewardRouter.timeToNextDistribution(addr), timeToNext, "time to next distribution");
        assertEq(childToParentRewardRouter.canDistribute(addr), canDistribute, "can distribute");
        assertEq(childToParentRewardRouter.nextDistributions(addr), next, "next distribution time");
    }
}
