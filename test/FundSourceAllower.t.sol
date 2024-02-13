// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../src/FundSourceApprover/FundSourceAllower.sol";
import "./util/TestToken.sol";

contract FundSourceAllowerTest is Test {
    uint256 sourceChainId = 123456;
    address ethDestination = address(1111_1);
    address admin = address(1111_2);
    address rando = address(1111_3);
    address funder = address(1111_4);
    FundSourceAllower fundSourceAllower;

    TestToken token;
    address tokenWhale = address(1111_5);

    address tokenDestination = address(1111_6);

    function setUp() external {
        fundSourceAllower = new FundSourceAllower({
            _sourceChaindId: sourceChainId,
            _ethDestination: ethDestination,
            _tokenDestination: tokenDestination,
            _admin: admin
        });
        vm.deal(funder, 1 ether);

        token = new TestToken(tokenWhale, 1000);
    }

    function testConstructor() external {
        assertEq(fundSourceAllower.sourceChaindId(), sourceChainId, "sourceChaindId set");
        assertEq(fundSourceAllower.ethDestination(), ethDestination, "destination set");
        assertEq(fundSourceAllower.admin(), admin, "admin set");
        assertFalse(fundSourceAllower.approved(), "approved initially set false");
    }

    function testRecieveNativeNotApproved() external {
        vm.prank(funder);
        address(fundSourceAllower).call{value: 1 ether}("");
        assertEq(address(fundSourceAllower).balance, 1 ether, "ether still in allower");
        assertEq(address(ethDestination).balance, 0, "ether not sent to destination");
    }

    function testTransferNativeFundsToDestinationNotApproved() external {
        vm.deal(address(fundSourceAllower), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(FundSourceAllower.NotApproved.selector));
        fundSourceAllower.transferEthToDestination();
    }

    function testTransferTokenToDestinationNotApproved() external {
        vm.prank(tokenWhale);
        token.transfer(address(fundSourceAllower), 10);
        vm.expectRevert(abi.encodeWithSelector(FundSourceAllower.NotApproved.selector));
        fundSourceAllower.transferTokenToDestination(address(token));
    }

    function testApproveAndReceiveNative() external {
        vm.prank(admin);
        fundSourceAllower.setApproved();
        vm.prank(funder);
        address(fundSourceAllower).call{value: 1 ether}("");
        assertEq(address(fundSourceAllower).balance, 0, "ether tranfered out of allower");
        assertEq(address(ethDestination).balance, 1 ether, "ether sent to destination");
    }

    function testApproveAndTransferNativeFundsToDestination() external {
        vm.prank(funder);
        address(fundSourceAllower).call{value: 1 ether}("");
        vm.prank(admin);
        fundSourceAllower.setApproved();
        assertEq(address(fundSourceAllower).balance, 1 ether, "ether still in allower");
        fundSourceAllower.transferEthToDestination();
        assertEq(address(fundSourceAllower).balance, 0, "ether tranfered out of allower");
        assertEq(address(ethDestination).balance, 1 ether, "ether sent to destination");
    }

    function testApproveAndTransferTokenToDestination() external {
        vm.prank(tokenWhale);
        token.transfer(address(fundSourceAllower), 10);
        vm.prank(admin);
        fundSourceAllower.setApproved();
        assertEq(token.balanceOf(address(fundSourceAllower)), 10, "token still in allower");
        fundSourceAllower.transferTokenToDestination(address(token));
        assertEq(token.balanceOf(address(fundSourceAllower)), 0, "token tranfered out of allower");
        assertEq(token.balanceOf(tokenDestination), 10, "token tranfered out of allower");
    }

    function testOnlyAdminCanSetApproved() external {
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(FundSourceAllower.NotFromAdmin.selector, rando));
        fundSourceAllower.setApproved();
    }

    function testOnlyAdminCanSetNotApproved() external {
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(FundSourceAllower.NotFromAdmin.selector, rando));
        fundSourceAllower.setNotApproved();
    }

    function testApproveWorks() external {
        vm.prank(admin);
        fundSourceAllower.setApproved();
        assertTrue(fundSourceAllower.approved(), "approved set");
    }
}
