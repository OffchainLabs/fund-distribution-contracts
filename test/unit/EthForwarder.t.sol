// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/TopUp/EthForwarder.sol";

import "../mocks/Empty.sol";

import "forge-std/Test.sol";

contract EthForwarderTest is Test {
    EthForwarder forwarder;
    address owner = address(0x1111);
    address pauser = address(0x5555);
    address recipient = address(0x2222);
    address remainder = address(0x3333);

    event Forwarded(uint256 toRecipient, uint256 toRemainder);
    event RecipientSet(address recipient);
    event RemainderSet(address remainder);
    event TargetSet(uint256 target);

    function setUp() public {
        forwarder = new EthForwarder(owner, pauser, recipient, remainder, 10 ether);
    }

    function testConstructor() public {
        assertEq(forwarder.owner(), owner);
        assertEq(forwarder.pauser(), pauser);
        assertEq(forwarder.recipient(), recipient);
        assertEq(forwarder.remainder(), remainder);
        assertEq(forwarder.targetBalance(), 10 ether);
    }

    function testForwardAmountsSplitsShortfallAndRest() public {
        vm.deal(address(forwarder), 20 ether);
        vm.deal(recipient, 3 ether);
        (uint256 toRecipient, uint256 toRemainder) = forwarder.forwardAmounts();
        assertEq(toRecipient, 7 ether);
        assertEq(toRemainder, 13 ether);
    }

    function testForwardAmountsLimitedByBalance() public {
        vm.deal(address(forwarder), 2 ether);
        vm.deal(recipient, 3 ether);
        (uint256 toRecipient, uint256 toRemainder) = forwarder.forwardAmounts();
        assertEq(toRecipient, 2 ether);
        assertEq(toRemainder, 0);
    }

    function testForwardAmountsRecipientAboveTarget() public {
        vm.deal(address(forwarder), 5 ether);
        vm.deal(recipient, 11 ether);
        (uint256 toRecipient, uint256 toRemainder) = forwarder.forwardAmounts();
        assertEq(toRecipient, 0);
        assertEq(toRemainder, 5 ether);
    }

    function testForward() public {
        vm.deal(address(forwarder), 20 ether);
        vm.deal(recipient, 3 ether);

        vm.expectEmit(false, false, false, true, address(forwarder));
        emit Forwarded(7 ether, 13 ether);
        forwarder.forward();

        assertEq(recipient.balance, 10 ether);
        assertEq(remainder.balance, 13 ether);
        assertEq(address(forwarder).balance, 0);
    }

    function testForwardRecipientRejects() public {
        forwarder = new EthForwarder(owner, pauser, address(new Empty()), remainder, 10 ether);
        vm.deal(address(forwarder), 20 ether);

        vm.expectRevert(AbsTopUp.TransferFailed.selector);
        forwarder.forward();
    }

    function testForwardRemainderRejects() public {
        forwarder = new EthForwarder(owner, pauser, recipient, address(new Empty()), 10 ether);
        vm.deal(address(forwarder), 20 ether);

        vm.expectRevert(AbsTopUp.TransferFailed.selector);
        forwarder.forward();
    }

    function testForwardZeroSendsNothing() public {
        forwarder = new EthForwarder(owner, pauser, address(new Empty()), address(new Empty()), 10 ether);

        vm.expectEmit(false, false, false, true, address(forwarder));
        emit Forwarded(0, 0);
        forwarder.forward();
    }

    function testReceiveEth() public {
        (bool ok,) = address(forwarder).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(forwarder).balance, 1 ether);
    }

    function testPauseBlocksForward() public {
        vm.deal(address(forwarder), 20 ether);
        vm.prank(pauser);
        forwarder.pause();

        vm.expectRevert("Pausable: paused");
        forwarder.forward();
    }

    function testUnpauseResumesForward() public {
        vm.deal(address(forwarder), 20 ether);
        vm.deal(recipient, 3 ether);
        vm.prank(pauser);
        forwarder.pause();
        vm.prank(owner);
        forwarder.unpause();

        forwarder.forward();
        assertEq(recipient.balance, 10 ether);
        assertEq(remainder.balance, 13 ether);
        assertEq(address(forwarder).balance, 0);
    }

    function testReceiveWhilePaused() public {
        vm.prank(pauser);
        forwarder.pause();

        (bool ok,) = address(forwarder).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(forwarder).balance, 1 ether);
    }

    function testSetRecipient() public {
        address other = address(0x4444);
        vm.deal(address(forwarder), 20 ether);

        vm.expectEmit(false, false, false, true, address(forwarder));
        emit RecipientSet(other);
        vm.prank(owner);
        forwarder.setRecipient(other);

        forwarder.forward();
        assertEq(other.balance, 10 ether);
        assertEq(recipient.balance, 0);
    }

    function testSetRemainder() public {
        address other = address(0x4444);
        vm.deal(address(forwarder), 20 ether);

        vm.expectEmit(false, false, false, true, address(forwarder));
        emit RemainderSet(other);
        vm.prank(owner);
        forwarder.setRemainder(other);

        forwarder.forward();
        assertEq(other.balance, 10 ether);
        assertEq(remainder.balance, 0);
    }

    function testSetTarget() public {
        vm.deal(address(forwarder), 20 ether);
        vm.deal(recipient, 3 ether);

        vm.expectEmit(false, false, false, true, address(forwarder));
        emit TargetSet(15 ether);
        vm.prank(owner);
        forwarder.setTarget(15 ether);
        assertEq(forwarder.targetBalance(), 15 ether);

        forwarder.forward();
        assertEq(recipient.balance, 15 ether);
        assertEq(remainder.balance, 8 ether);
    }

    function testSetTargetZeroSendsAllToRemainder() public {
        vm.deal(address(forwarder), 20 ether);

        vm.expectEmit(false, false, false, true, address(forwarder));
        emit TargetSet(0);
        vm.prank(owner);
        forwarder.setTarget(0);

        forwarder.forward();
        assertEq(recipient.balance, 0);
        assertEq(remainder.balance, 20 ether);
    }

    function testSettersOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        forwarder.setRecipient(address(0x4444));
        vm.expectRevert("Ownable: caller is not the owner");
        forwarder.setRemainder(address(0x4444));
        vm.expectRevert("Ownable: caller is not the owner");
        forwarder.setTarget(1);
    }
}
