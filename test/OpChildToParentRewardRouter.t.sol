// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../src/FeeRouter/OpChildToParentRewardRouter.sol";
import "./util/TestToken.sol";
import "./util/OpStandardBridgeMock.sol";
import "./Empty.sol";

import "forge-std/Test.sol";

contract TestOpChildToParentRewardRouter is OpChildToParentRewardRouter {
    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress
    )
        OpChildToParentRewardRouter(
            _parentChainTarget,
            _minDistributionIntervalSeconds,
            _parentChainTokenAddress,
            _childChainTokenAddress
        )
    {}

    function triggerSendNative(uint256 amount) external {
        _sendNative(amount);
    }

    function triggerSendToken(uint256 amount) external {
        _sendToken(amount);
    }
}

contract OpChildToParentRewardRouterTest is Test {
    address parentToken = address(0x202020);
    address parentTarget = address(0x404040);
    TestToken token;
    address me = address(111_1);
    TestOpChildToParentRewardRouter childToParentRewardRouter;
    uint256 minDistributionIntervalSeconds = 20;

    event Approval(address indexed, address indexed, uint256);
    event BridgeEthTo(address, uint256, uint32, bytes);
    event BridgeERC20To(address, address, address, uint256, uint32, bytes);

    function setUp() public {
        vm.deal(me, 10 ether);

        vm.prank(me);
        token = new TestToken(100 ether);

        vm.etch(0x4200000000000000000000000000000000000010, address(new OpStandardBridgeMock()).code);

        childToParentRewardRouter = new TestOpChildToParentRewardRouter(
            parentTarget, minDistributionIntervalSeconds, parentToken, address(token)
        );
    }

    function testSanityCheck() public {
        vm.etch(0x4200000000000000000000000000000000000010, "");
        vm.expectRevert(OpChildToParentRewardRouter.NotOpStack.selector);
        new TestOpChildToParentRewardRouter(parentTarget, minDistributionIntervalSeconds, parentToken, address(token));
    }

    function testSendNative(uint64 amount) external {
        vm.deal(address(childToParentRewardRouter), 2 * uint256(amount));
        vm.expectEmit(false, false, false, true, 0x4200000000000000000000000000000000000010);
        emit BridgeEthTo(parentTarget, amount, 0, bytes(""));
        childToParentRewardRouter.triggerSendNative(amount);
    }

    function testSendToken(uint256 amount) external {
        amount = bound(amount, 1, 10 ether);
        vm.prank(me);
        token.transfer(address(childToParentRewardRouter), 2 * amount);

        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(childToParentRewardRouter), 0x4200000000000000000000000000000000000010, amount);
        vm.expectEmit(false, false, false, true, 0x4200000000000000000000000000000000000010);
        emit BridgeERC20To(address(token), parentToken, parentTarget, amount, 0, "");
        childToParentRewardRouter.triggerSendToken(amount);
    }
}
