// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../src/FundSourceApprover/FundSourceAllower/NativeFundSourceAllower.sol";

contract NativeFundSourceAllowerTest is Test {
    uint256 sourceChainId = 123456;
    address destination = address(1111_1);
    address admin = address(1111_2);
    address rando = address(1111_3);
    address funder = address(1111_4);
    NativeFundSourceAllower nativeFundSourceAllower;

    function setUp() external {
        nativeFundSourceAllower =
            new NativeFundSourceAllower({_sourceChaindId: sourceChainId, _destination: destination, _admin: admin});
        vm.deal(funder, 1 ether);
    }

    function testConstructor() external {
        assertEq(nativeFundSourceAllower.sourceChaindId(), sourceChainId, "sourceChaindId set");
        assertEq(nativeFundSourceAllower.destination(), destination, "destination set");
        assertEq(nativeFundSourceAllower.admin(), admin, "admin set");
        assertFalse(nativeFundSourceAllower.approved(), "approved initially set false");
    }

    function testRecieveNotApproved() external {
        vm.prank(funder);
        address(nativeFundSourceAllower).call{value: 1 ether}("");
        assertEq(address(nativeFundSourceAllower).balance, 1 ether, "ether still in allower");
        assertEq(address(destination).balance, 0, "ether not sent to destination");
    }

    function testTransferFundsToDestinationNotApproved() external {
        vm.deal(address(nativeFundSourceAllower), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(FundSourceAllowerBase.NotApproved.selector));
        nativeFundSourceAllower.transferFundsToDestination();
    }
}
