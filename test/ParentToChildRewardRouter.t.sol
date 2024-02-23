// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "./util/InboxMock.sol";
import "../src/FeeRouter/ParentToChildRewardRouter.sol";

// TODO: update
// contract ParentToChildRewardRouterTest is Test {
//     ParentToChildRewardRouter parentToChildRewardRouter;
//     InboxMock inbox;
//     address me;

//     uint256 minDistributionIntervalSeconds = 20;

//     function setUp() public {
//         inbox = new InboxMock();
//         parentToChildRewardRouter = new ParentToChildRewardRouter({
//             _inbox: address(inbox),
//             _destination: address(1234),
//             _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
//             _minGasPrice: 1,
//             _minGasLimit: 1 ether
//         });
//         vm.deal(me, 10 ether);
//     }

//     function testrouteNativeFunds() external {
//         vm.startPrank(me);
//         (bool sent, ) = address(parentToChildRewardRouter).call{value: 1 ether}(
//             ""
//         );
//         assertTrue(sent, "funds sent");
//         assertEq(
//             address(parentToChildRewardRouter).balance,
//             1 ether,
//             "funds received"
//         );
//         assertEq(inbox.msgNum(), 0, "inbox msg num 0");
//         parentToChildRewardRouter.routeNativeFunds{value: 2 ether}({
//             maxSubmissionCost: 1 ether,
//             gasLimit: 1 ether,
//             maxFeePerGas: 1
//         });

//         assertEq(inbox.msgNum(), 1, "create retryable ticket called");
//         assertEq(address(parentToChildRewardRouter).balance, 0, "funds routed");

//         vm.stopPrank();
//     }

//     function testRevertsWithInsufficientValue() external {
//         vm.startPrank(me);

//         (bool sent, bytes memory data) = address(parentToChildRewardRouter)
//             .call{value: 1 ether}("");
//         assertTrue(sent, "funds sent");

//         vm.expectRevert(
//             abi.encodeWithSelector(IncorrectValue.selector, 2 ether, 1.9 ether)
//         );
//         parentToChildRewardRouter.routeNativeFunds{value: 1.9 ether}({
//             maxSubmissionCost: 1 ether,
//             gasLimit: 1 ether,
//             maxFeePerGas: 1
//         });
//         assertEq(inbox.msgNum(), 0, "create retryable ticket not called");

//         vm.stopPrank();
//     }
//     function testCantRouteTooSoon() public {
//         vm.startPrank(me);
//         (bool sent, ) = address(parentToChildRewardRouter).call{value: 1 ether}(
//             ""
//         );
//         assertTrue(sent, "funds sent");
//         parentToChildRewardRouter.routeNativeFunds{value: 2 ether}({
//             maxSubmissionCost: 1 ether,
//             gasLimit: 1 ether,
//             maxFeePerGas: 1
//         });
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 DistributionTooSoon.selector,
//                 block.timestamp,
//                 parentToChildRewardRouter.nextDistribution()
//             )
//         );
//         parentToChildRewardRouter.routeNativeFunds{value: 2 ether}({
//             maxSubmissionCost: 1 ether,
//             gasLimit: 1 ether,
//             maxFeePerGas: 1
//         });
//         vm.stopPrank();
//     }
// }
