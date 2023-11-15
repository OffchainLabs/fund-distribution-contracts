// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "../src/FeeRouter/RewardReceiver.sol";
import "./util/ArbSysMock.sol";
import "./Empty.sol";

import "forge-std/Test.sol";

contract RewardReceiverTest is Test {
    event ArbSysL2ToL1Tx(
        address from,
        address to,
        uint256 value,
        bytes indexed data
    );

    address me = address(111_1);
    RewardReceiver rewardReceiver;
    uint256 minDistributionIntervalSeconds = 20;

    function setUp() public {
        vm.etch(address(100), address(new ArbSysMock()).code);
        vm.deal(address(me), 10 ether);
        rewardReceiver = new RewardReceiver(
            address(1111_2),
            minDistributionIntervalSeconds
        );
    }

    function testSendFunds() external {
        vm.startPrank(address(me));
        (bool sent, bytes memory data) = payable(address(rewardReceiver)).call{
            value: 1 ether
        }("");
        assertTrue(sent, "funds sent");
        assertEq(address(rewardReceiver).balance, 0, "funds routed");
        vm.stopPrank();
    }

    function testCantSendFundsTooSoon() external {
        vm.startPrank(me);
        (bool sent, bytes memory data) = address(rewardReceiver).call{
            value: 1 ether
        }("");
        assertTrue(sent, "funds sent");
        (sent, data) = address(rewardReceiver).call{value: 1 ether}("");
        assertTrue(sent, "funds sent");
        assertEq(
            address(rewardReceiver).balance,
            1 ether,
            "funds routed only once"
        );

        rewardReceiver.sendFunds();
        assertEq(
            address(rewardReceiver).balance,
            1 ether,
            "funds still routed only once"
        );
        vm.warp(block.timestamp + minDistributionIntervalSeconds);
        rewardReceiver.sendFunds();

        assertEq(address(rewardReceiver).balance, 0, "funds routed after warp");
        vm.stopPrank();
    }
}
