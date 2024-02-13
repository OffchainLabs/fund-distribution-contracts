// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../src/FundSourceApprover/FundSourceAllowerAdmin.sol";
import "../src/FundSourceApprover/FundSourceAllower.sol";

contract FundSourceAllowerAdminTest is Test {
    address nativeFundDestination = address(111_1);
    address erc20FundDestination = address(111_2);
    address owner = address(111_3);
    address rando = address(111_4);
    FundSourceAllowerAdmin fundSourceAllowerAdmin;
    uint256 chainID = 12345;

    function setUp() external {
        fundSourceAllowerAdmin = new FundSourceAllowerAdmin(owner, nativeFundDestination, erc20FundDestination);
    }

    function testConstructor() external {
        assertEq(owner, fundSourceAllowerAdmin.owner(), "owner set");
        assertEq(erc20FundDestination, fundSourceAllowerAdmin.tokenDestination(), "tokenDestination set");
        assertEq(nativeFundDestination, fundSourceAllowerAdmin.ethDestination(), "ethDestination set");
    }

    function testOnlyOwnerCanCreate() external {
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        fundSourceAllowerAdmin.createFundSourceAllower(chainID);
    }

    function testOnlyOwnerCanApprove() external {
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        fundSourceAllowerAdmin.setApproved(payable(address(1)));
    }

    function testOnlyOwnerCanUnApprove() external {
        vm.prank(rando);
        vm.expectRevert("Ownable: caller is not the owner");
        fundSourceAllowerAdmin.setNotApproved(payable(address(1)));
    }

    function testFundSourceAllowerIsCreatedAtCreate2Address() external {
        address calcedAddr = fundSourceAllowerAdmin.getFundSourceAllowerCreate2Address(chainID);
        vm.prank(owner);
        address fsaAddr = fundSourceAllowerAdmin.createFundSourceAllower(chainID);
        assertEq(calcedAddr, fsaAddr, "fsa created");
    }

    function testFundSourceAllowerIsCreatedCorrectly() external {
        vm.startPrank(owner);
        FundSourceAllower fundSourceAllower =
            FundSourceAllower(payable(fundSourceAllowerAdmin.createFundSourceAllower(chainID)));
        assertEq(fundSourceAllower.sourceChaindId(), chainID, "chain id set");
        assertEq(fundSourceAllower.ethDestination(), nativeFundDestination, "ethDestination set");
        assertEq(fundSourceAllower.tokenDestination(), erc20FundDestination, "tokenDestination set");
        assertEq(fundSourceAllower.admin(), address(fundSourceAllowerAdmin), "fundSourceAllowerAdmin set");
    }

    function testApprovedAndUnApproveWorks() external {
        vm.startPrank(owner);
        FundSourceAllower fundSourceAllower =
            FundSourceAllower(payable(fundSourceAllowerAdmin.createFundSourceAllower(chainID)));
        assertFalse(fundSourceAllower.approved(), "not approved");

        fundSourceAllowerAdmin.setApproved(payable(address(fundSourceAllower)));
        assertTrue(fundSourceAllower.approved(), "approved");

        fundSourceAllowerAdmin.setNotApproved(payable(address(fundSourceAllower)));
        assertFalse(fundSourceAllower.approved(), "not approved");

        vm.stopPrank();
    }

    function testUnApproveWorks() external {}
}
