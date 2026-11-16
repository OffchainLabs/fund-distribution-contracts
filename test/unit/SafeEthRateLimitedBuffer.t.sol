// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/RateLimitedBuffer/SafeEthRateLimitedBuffer.sol";
import "../mocks/SafeMock.sol";
import "../mocks/Empty.sol";

import "forge-std/Test.sol";

contract SafeEthRateLimitedBufferTest is Test {
    SafeMock safe;
    SafeEthRateLimitedBuffer buffer;
    address owner = address(0x1111);
    address recipient = address(0x2222);

    function setUp() public {
        safe = new SafeMock();
        buffer = new SafeEthRateLimitedBuffer(ISafe(address(safe)), owner, recipient, 10 ether, 4 ether, 100);
        safe.enableModule(address(buffer));
    }

    function testConstructor() public {
        assertEq(address(buffer.safe()), address(safe));
        assertEq(buffer.owner(), owner);
    }

    function testForwardFromSafe() public {
        vm.deal(address(safe), 20 ether);
        vm.deal(recipient, 9 ether);

        buffer.forward();

        assertEq(recipient.balance, 10 ether);
        assertEq(address(safe).balance, 19 ether);
    }

    function testForwardLimitedBySafeFunds() public {
        vm.deal(address(safe), 1 ether);
        vm.deal(address(buffer), 20 ether);

        buffer.forward();

        assertEq(recipient.balance, 1 ether);
    }

    function testForwardModuleNotEnabled() public {
        buffer = new SafeEthRateLimitedBuffer(ISafe(address(safe)), owner, recipient, 10 ether, 4 ether, 100);
        vm.deal(address(safe), 20 ether);

        vm.expectRevert("GS104");
        buffer.forward();
    }

    function testForwardRecipientRejects() public {
        buffer = new SafeEthRateLimitedBuffer(ISafe(address(safe)), owner, address(new Empty()), 10 ether, 4 ether, 100);
        safe.enableModule(address(buffer));
        vm.deal(address(safe), 20 ether);

        vm.expectRevert(SafeEthRateLimitedBuffer.SafeTransferFailed.selector);
        buffer.forward();
    }
}
