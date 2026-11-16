// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/TopUp/EthRateLimitedBuffer.sol";

import "../mocks/Empty.sol";

import "forge-std/Test.sol";

contract EthRateLimitedBufferTest is Test {
    EthRateLimitedBuffer buffer;
    address owner = address(0x1111);
    address recipient = address(0x2222);
    address pauser = address(0x4444);

    event Forwarded(uint256 amount);
    event PauserSet(address pauser);
    event RecipientSet(address recipient);
    event TargetSet(uint256 target);
    event MaxAllowanceSet(uint256 maxAllowance);
    event WindowSet(uint256 window);

    function setUp() public {
        buffer = new EthRateLimitedBuffer(owner, pauser, recipient, 10 ether, 4 ether, 100);
    }

    function testConstructor() public {
        assertEq(buffer.owner(), owner);
        assertEq(buffer.pauser(), pauser);
        assertEq(buffer.recipient(), recipient);
        assertEq(buffer.targetBalance(), 10 ether);
        assertEq(buffer.maxAllowance(), 4 ether);
        assertEq(buffer.window(), 100);
        assertEq(buffer.allowance(), 4 ether);
    }

    function testConstructorZeroWindow() public {
        vm.expectRevert(EthRateLimitedBuffer.ZeroWindow.selector);
        new EthRateLimitedBuffer(owner, pauser, recipient, 10 ether, 4 ether, 0);
    }

    function testForwardLimitedByAllowance() public {
        vm.deal(address(buffer), 20 ether);
        vm.deal(recipient, 3 ether);
        assertEq(buffer.forwardAmount(), 4 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit Forwarded(4 ether);
        buffer.forward();

        assertEq(recipient.balance, 7 ether);
        assertEq(address(buffer).balance, 16 ether);
        assertEq(buffer.allowance(), 0);
    }

    function testAllowanceRefillsLinearlyUpToMax() public {
        vm.deal(address(buffer), 20 ether);
        buffer.forward();
        assertEq(buffer.allowance(), 0);

        vm.warp(block.timestamp + 25);
        assertEq(buffer.allowance(), 1 ether);

        vm.warp(block.timestamp + 50);
        assertEq(buffer.allowance(), 3 ether);

        vm.warp(block.timestamp + 1000);
        assertEq(buffer.allowance(), 4 ether);
    }

    function testReceiveEth() public {
        (bool ok,) = address(buffer).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(buffer).balance, 1 ether);
    }

    function testForwardRecipientRejects() public {
        buffer = new EthRateLimitedBuffer(owner, pauser, address(new Empty()), 10 ether, 4 ether, 100);
        vm.deal(address(buffer), 20 ether);

        vm.expectRevert(EthRateLimitedBuffer.TransferFailed.selector);
        buffer.forward();
    }

    function testForwardLimitedByShortfall() public {
        vm.deal(address(buffer), 20 ether);
        vm.deal(recipient, 9 ether);
        buffer.forward();

        assertEq(recipient.balance, 10 ether);
        assertEq(buffer.allowance(), 3 ether);
    }

    function testForwardLimitedByFunds() public {
        vm.deal(address(buffer), 1 ether);
        buffer.forward();

        assertEq(recipient.balance, 1 ether);
        assertEq(buffer.allowance(), 3 ether);
    }

    function testForwardAmountZeroAboveTarget() public {
        vm.deal(address(buffer), 20 ether);
        vm.deal(recipient, 11 ether);
        assertEq(buffer.forwardAmount(), 0);
    }

    function testForwardZeroSendsNothing() public {
        buffer = new EthRateLimitedBuffer(owner, pauser, address(new Empty()), 10 ether, 4 ether, 100);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit Forwarded(0);
        buffer.forward();
    }

    function testForwardZeroKeepsAllowance() public {
        vm.deal(address(buffer), 4 ether);
        buffer.forward();
        vm.warp(block.timestamp + 10);
        assertEq(buffer.allowance(), 0.4 ether);

        buffer.forward();
        assertEq(buffer.allowance(), 0.4 ether);
    }

    function testPauseBlocksForward() public {
        vm.deal(address(buffer), 20 ether);

        vm.prank(pauser);
        buffer.pause();

        vm.expectRevert("Pausable: paused");
        buffer.forward();
    }

    function testUnpauseResumesForward() public {
        vm.deal(address(buffer), 20 ether);
        buffer.forward();
        vm.prank(pauser);
        buffer.pause();
        vm.warp(block.timestamp + 50);

        vm.prank(owner);
        buffer.unpause();
        buffer.forward();

        assertEq(recipient.balance, 6 ether);
    }

    function testPauseOnlyPauserOrOwner() public {
        vm.expectRevert(AbsOwnablePausable.NotPauser.selector);
        buffer.pause();

        vm.prank(owner);
        buffer.pause();
        assertTrue(buffer.paused());
    }

    function testUnpauseOnlyOwner() public {
        vm.prank(pauser);
        buffer.pause();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(pauser);
        buffer.unpause();
    }

    function testSetPauser() public {
        address other = address(0x3333);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit PauserSet(other);
        vm.prank(owner);
        buffer.setPauser(other);
        assertEq(buffer.pauser(), other);

        vm.expectRevert(AbsOwnablePausable.NotPauser.selector);
        vm.prank(pauser);
        buffer.pause();

        vm.prank(other);
        buffer.pause();
        assertTrue(buffer.paused());
    }

    function testSetRecipient() public {
        address other = address(0x3333);
        vm.deal(address(buffer), 20 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit RecipientSet(other);
        vm.prank(owner);
        buffer.setRecipient(other);

        buffer.forward();
        assertEq(other.balance, 4 ether);
        assertEq(recipient.balance, 0);
    }

    function testSetTarget() public {
        vm.deal(address(buffer), 20 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit TargetSet(1 ether);
        vm.prank(owner);
        buffer.setTarget(1 ether);

        buffer.forward();
        assertEq(recipient.balance, 1 ether);
    }

    function testSettersOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        buffer.setPauser(address(0x3333));
        vm.expectRevert("Ownable: caller is not the owner");
        buffer.setRecipient(address(0x3333));
        vm.expectRevert("Ownable: caller is not the owner");
        buffer.setTarget(1);
        vm.expectRevert("Ownable: caller is not the owner");
        buffer.setMaxAllowance(1);
        vm.expectRevert("Ownable: caller is not the owner");
        buffer.setWindow(1);
    }

    function testSetMaxAllowanceLowerClamps() public {
        vm.deal(address(buffer), 20 ether);
        buffer.forward();
        vm.warp(block.timestamp + 50);
        assertEq(buffer.allowance(), 2 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit MaxAllowanceSet(1 ether);
        vm.prank(owner);
        buffer.setMaxAllowance(1 ether);
        assertEq(buffer.allowance(), 1 ether);
    }

    function testSetMaxAllowanceRaiseKeepsCurrent() public {
        vm.deal(address(buffer), 20 ether);
        buffer.forward();
        vm.warp(block.timestamp + 50);

        vm.prank(owner);
        buffer.setMaxAllowance(8 ether);
        assertEq(buffer.allowance(), 2 ether);

        vm.warp(block.timestamp + 25);
        assertEq(buffer.allowance(), 4 ether);

        vm.warp(block.timestamp + 1000);
        assertEq(buffer.allowance(), 8 ether);
    }

    function testSetWindowKeepsAccrued() public {
        vm.deal(address(buffer), 20 ether);
        buffer.forward();
        vm.warp(block.timestamp + 50);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit WindowSet(200);
        vm.prank(owner);
        buffer.setWindow(200);
        assertEq(buffer.allowance(), 2 ether);

        vm.warp(block.timestamp + 50);
        assertEq(buffer.allowance(), 3 ether);
    }

    function testSetWindowZero() public {
        vm.expectRevert(EthRateLimitedBuffer.ZeroWindow.selector);
        vm.prank(owner);
        buffer.setWindow(0);
    }

    function testMaxUint256AllowanceDoesNotOverflow() public {
        uint256 max = type(uint256).max;
        buffer = new EthRateLimitedBuffer(owner, pauser, recipient, 10 ether, max, 100);
        vm.deal(address(buffer), 30 ether);

        vm.warp(block.timestamp + 2);
        assertEq(buffer.allowance(), max);
        buffer.forward();
        assertEq(recipient.balance, 10 ether);
        assertEq(buffer.allowance(), max - 10 ether);

        vm.warp(block.timestamp + 2);
        assertEq(buffer.allowance(), max);
        vm.deal(recipient, 0);
        buffer.forward();
        assertEq(recipient.balance, 10 ether);
        vm.prank(owner);
        buffer.setMaxAllowance(max);
        vm.prank(owner);
        buffer.setWindow(200);

        vm.warp(block.timestamp + 1000);
        assertEq(buffer.allowance(), max);
        vm.deal(recipient, 0);
        buffer.forward();
        assertEq(recipient.balance, 10 ether);
        vm.prank(owner);
        buffer.setWindow(100);
        vm.prank(owner);
        buffer.setMaxAllowance(4 ether);
        assertEq(buffer.allowance(), 4 ether);
    }

    function testFuzzAllowanceMatchesFormula(uint256 max, uint256 window, uint256 spent, uint256 elapsed) public {
        window = bound(window, 1, type(uint64).max);
        spent = bound(spent, 0, max);
        elapsed = bound(elapsed, 0, type(uint64).max);
        buffer = new EthRateLimitedBuffer(owner, pauser, recipient, type(uint256).max, max, window);
        vm.deal(address(buffer), spent);
        buffer.forward();
        uint256 stored = max - spent;
        assertEq(buffer.allowance(), stored);

        vm.warp(block.timestamp + elapsed);
        uint256 actual = buffer.allowance();
        assertLe(actual, max);

        if (elapsed != 0 && max > type(uint256).max / elapsed) return;
        uint256 refill = max * elapsed / window;
        if (stored > type(uint256).max - refill) return;
        assertEq(actual, stored + refill < max ? stored + refill : max);
    }
}
