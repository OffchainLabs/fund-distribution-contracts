// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./util/InboxMock.sol";
import "../src/FeeRouter/RewardRouter.sol";

contract RewardRouterTest is Test {
    RewardRouter rewardRouter;
    InboxMock inbox;
    address me;

    function setUp() public {
        inbox = new InboxMock();
        rewardRouter = new RewardRouter({
            _inbox: address(inbox),
            _destination: address(1234)
        });
        vm.deal(me, 10 ether);
    }

    function testRouteFunds() external {
        vm.startPrank(me);
        (bool sent, ) = address(rewardRouter).call{value: 1 ether}("");
        assertTrue(sent, "funds sent");
        assertEq(address(rewardRouter).balance, 1 ether, "funds received");
        assertEq(inbox.msgNum(), 0, "inbox msg num 0");
        rewardRouter.routeFunds{value: 2 ether}({
            maxSubmissionCost: 1 ether,
            gasLimit: 1 ether,
            maxFeePerGas: 1
        });

        assertEq(inbox.msgNum(), 1, "create retryable ticket called");
        assertEq(address(rewardRouter).balance, 0, "funds routed");

        vm.stopPrank();
    }

    function testRevertsWithInsufficientValue() external {
        vm.startPrank(me);

        (bool sent, bytes memory data) = address(rewardRouter).call{
            value: 1 ether
        }("");
        assertTrue(sent, "funds sent");

        vm.expectRevert(
            abi.encodeWithSelector(
                InsufficientValue.selector,
                2 ether,
                1.9 ether
            )
        );
        rewardRouter.routeFunds{value: 1.9 ether}({
            maxSubmissionCost: 1 ether,
            gasLimit: 1 ether,
            maxFeePerGas: 1
        });
        assertEq(inbox.msgNum(), 0, "create retryable ticket not called");

        vm.stopPrank();
    }
}
