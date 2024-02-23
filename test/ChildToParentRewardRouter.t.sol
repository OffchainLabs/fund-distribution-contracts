// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../src/FeeRouter/ChildToParentRewardRouter.sol";
import "./util/ArbSysMock.sol";
import "./Empty.sol";

import "forge-std/Test.sol";
// TODO: update
// contract ChildToParentRewardRouterTest is Test {
//     event ArbSysL2ToL1Tx(
//         address from,
//         address to,
//         uint256 value,
//         bytes indexed data
//     );

//     address me = address(111_1);
//     ChildToParentRewardRouter childToParentRewardRouter;
//     uint256 minDistributionIntervalSeconds = 20;

//     function setUp() public {
//         vm.etch(address(100), address(new ArbSysMock()).code);
//         vm.deal(address(me), 10 ether);
//         childToParentRewardRouter = new ChildToParentRewardRouter(
//             address(1111_2),
//             minDistributionIntervalSeconds
//         );
//     }

//     function testrouteNativeFunds() external {
//         vm.startPrank(address(me));
//         (bool sent, ) = payable(address(childToParentRewardRouter)).call{value: 1 ether}(
//             ""
//         );
//         assertTrue(sent, "funds sent");
//         assertEq(address(childToParentRewardRouter).balance, 0, "funds routed");
//         vm.stopPrank();
//     }

//     function testCantrouteNativeFundsTooSoon() external {
//         vm.startPrank(me);
//         (bool sent, ) = address(childToParentRewardRouter).call{value: 1 ether}("");
//         assertTrue(sent, "funds sent");
//         (sent, ) = address(childToParentRewardRouter).call{value: 1 ether}("");
//         assertTrue(sent, "funds sent");
//         assertEq(
//             address(childToParentRewardRouter).balance,
//             1 ether,
//             "funds routed only once"
//         );

//         childToParentRewardRouter.routeNativeFunds();
//         assertEq(
//             address(childToParentRewardRouter).balance,
//             1 ether,
//             "funds still routed only once"
//         );
//         vm.warp(block.timestamp + minDistributionIntervalSeconds);
//         childToParentRewardRouter.routeNativeFunds();

//         assertEq(address(childToParentRewardRouter).balance, 0, "funds routed after warp");
//         vm.stopPrank();
//     }
// }
