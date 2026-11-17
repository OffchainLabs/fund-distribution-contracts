// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/TopUp/SafeEthRateLimitedBuffer.sol";

import "../mocks/SafeMock.sol";
import "../mocks/Empty.sol";

import "forge-std/Test.sol";

contract SafeEthRateLimitedBufferTest is Test {
    SafeMock safe;
    SafeEthRateLimitedBuffer buffer;
    address recipient = address(0x2222);
    address pauser = address(0x4444);

    event Forwarded(uint256 amount);
    event PauserSet(address pauser);
    event RecipientSet(address recipient);
    event TargetBalanceSet(uint256 targetBalance);
    event MaxAllowanceSet(uint256 maxAllowance);
    event WindowSet(uint256 window);

    function setUp() public {
        safe = new SafeMock();
        buffer = _deploy(recipient, 10 ether, 4 ether, 100);
    }

    function _deploy(address _recipient, uint256 _targetBalance, uint256 _maxAllowance, uint256 _window)
        internal
        returns (SafeEthRateLimitedBuffer b)
    {
        b = new SafeEthRateLimitedBuffer(
            ISafe(address(safe)), pauser, _recipient, _targetBalance, _maxAllowance, _window
        );
        safe.enableModule(address(b));
    }

    function testConstructor() public {
        assertEq(address(buffer.safe()), address(safe));
        assertEq(buffer.pauser(), pauser);
        assertEq(buffer.recipient(), recipient);
        assertEq(buffer.targetBalance(), 10 ether);
        assertEq(buffer.maxAllowance(), 4 ether);
        assertEq(buffer.window(), 100);
        assertEq(buffer.allowance(), 4 ether);
    }

    function testConstructorZeroWindow() public {
        vm.expectRevert(SafeEthRateLimitedBuffer.ZeroWindow.selector);
        new SafeEthRateLimitedBuffer(ISafe(address(safe)), pauser, recipient, 10 ether, 4 ether, 0);
    }

    function testForwardLimitedByAllowance() public {
        vm.deal(address(safe), 20 ether);
        vm.deal(recipient, 3 ether);
        assertEq(buffer.forwardAmount(), 4 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit Forwarded(4 ether);
        buffer.forward();

        assertEq(recipient.balance, 7 ether);
        assertEq(address(safe).balance, 16 ether);
        assertEq(buffer.allowance(), 0);
    }

    function testAllowanceRefillsLinearlyUpToMax() public {
        vm.deal(address(safe), 20 ether);
        buffer.forward();
        assertEq(buffer.allowance(), 0);

        vm.warp(block.timestamp + 25);
        assertEq(buffer.allowance(), 1 ether);

        vm.warp(block.timestamp + 50);
        assertEq(buffer.allowance(), 3 ether);

        vm.warp(block.timestamp + 1000);
        assertEq(buffer.allowance(), 4 ether);
    }

    function testRejectsEth() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(buffer).call{value: 1 ether}("");
        assertFalse(ok);
        assertEq(address(buffer).balance, 0);
    }

    function testForwardIgnoresBufferBalance() public {
        vm.deal(address(safe), 1 ether);
        vm.deal(address(buffer), 20 ether);
        assertEq(buffer.forwardAmount(), 1 ether);

        buffer.forward();

        assertEq(recipient.balance, 1 ether);
        assertEq(address(safe).balance, 0);
        assertEq(address(buffer).balance, 20 ether);
    }

    function testForwardModuleNotEnabled() public {
        buffer = new SafeEthRateLimitedBuffer(ISafe(address(safe)), pauser, recipient, 10 ether, 4 ether, 100);
        vm.deal(address(safe), 20 ether);

        vm.expectRevert("GS104");
        buffer.forward();
    }

    function testForwardRecipientRejects() public {
        buffer = _deploy(address(new Empty()), 10 ether, 4 ether, 100);
        vm.deal(address(safe), 20 ether);

        vm.expectRevert(SafeEthRateLimitedBuffer.SafeTransferFailed.selector);
        buffer.forward();
    }

    function testForwardLimitedByShortfall() public {
        vm.deal(address(safe), 20 ether);
        vm.deal(recipient, 9 ether);
        buffer.forward();

        assertEq(recipient.balance, 10 ether);
        assertEq(address(safe).balance, 19 ether);
        assertEq(buffer.allowance(), 3 ether);
    }

    function testForwardLimitedByFunds() public {
        vm.deal(address(safe), 1 ether);
        buffer.forward();

        assertEq(recipient.balance, 1 ether);
        assertEq(buffer.allowance(), 3 ether);
    }

    function testForwardAmountZeroAboveTarget() public {
        vm.deal(address(safe), 20 ether);
        vm.deal(recipient, 11 ether);
        assertEq(buffer.forwardAmount(), 0);
    }

    function testForwardZeroSendsNothing() public {
        buffer = _deploy(address(new Empty()), 10 ether, 4 ether, 100);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit Forwarded(0);
        buffer.forward();
    }

    function testForwardZeroKeepsAllowance() public {
        vm.deal(address(safe), 4 ether);
        buffer.forward();
        vm.warp(block.timestamp + 10);
        assertEq(buffer.allowance(), 0.4 ether);

        buffer.forward();
        assertEq(buffer.allowance(), 0.4 ether);
    }

    function testPauseBlocksForward() public {
        vm.deal(address(safe), 20 ether);

        vm.prank(pauser);
        buffer.pause();

        vm.expectRevert("Pausable: paused");
        buffer.forward();
    }

    function testUnpauseResumesForward() public {
        vm.deal(address(safe), 20 ether);
        buffer.forward();
        vm.prank(pauser);
        buffer.pause();
        vm.warp(block.timestamp + 50);

        vm.prank(address(safe));
        buffer.unpause();
        buffer.forward();

        assertEq(recipient.balance, 6 ether);
    }

    function testPauseOnlyPauserOrSafe() public {
        vm.expectRevert(SafeEthRateLimitedBuffer.NotPauser.selector);
        buffer.pause();

        vm.prank(address(safe));
        buffer.pause();
        assertTrue(buffer.paused());
    }

    function testUnpauseOnlySafe() public {
        vm.prank(pauser);
        buffer.pause();

        vm.expectRevert(SafeEthRateLimitedBuffer.NotSafe.selector);
        vm.prank(pauser);
        buffer.unpause();

        vm.prank(address(safe));
        buffer.unpause();
        assertFalse(buffer.paused());
    }

    function testSetPauser() public {
        address other = address(0x3333);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit PauserSet(other);
        vm.prank(address(safe));
        buffer.setPauser(other);
        assertEq(buffer.pauser(), other);

        vm.expectRevert(SafeEthRateLimitedBuffer.NotPauser.selector);
        vm.prank(pauser);
        buffer.pause();

        vm.prank(other);
        buffer.pause();
        assertTrue(buffer.paused());
    }

    function testSetRecipient() public {
        address other = address(0x3333);
        vm.deal(address(safe), 20 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit RecipientSet(other);
        vm.prank(address(safe));
        buffer.setRecipient(other);

        buffer.forward();
        assertEq(other.balance, 4 ether);
        assertEq(recipient.balance, 0);
    }

    function testSetTargetBalance() public {
        vm.deal(address(safe), 20 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit TargetBalanceSet(1 ether);
        vm.prank(address(safe));
        buffer.setTargetBalance(1 ether);

        buffer.forward();
        assertEq(recipient.balance, 1 ether);
    }

    function testSettersOnlySafe() public {
        vm.expectRevert(SafeEthRateLimitedBuffer.NotSafe.selector);
        buffer.setPauser(address(0x3333));
        vm.expectRevert(SafeEthRateLimitedBuffer.NotSafe.selector);
        buffer.setRecipient(address(0x3333));
        vm.expectRevert(SafeEthRateLimitedBuffer.NotSafe.selector);
        buffer.setTargetBalance(1);
        vm.expectRevert(SafeEthRateLimitedBuffer.NotSafe.selector);
        buffer.setMaxAllowance(1);
        vm.expectRevert(SafeEthRateLimitedBuffer.NotSafe.selector);
        buffer.setWindow(1);
    }

    function testSetMaxAllowanceLowerClamps() public {
        vm.deal(address(safe), 20 ether);
        buffer.forward();
        vm.warp(block.timestamp + 50);
        assertEq(buffer.allowance(), 2 ether);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit MaxAllowanceSet(1 ether);
        vm.prank(address(safe));
        buffer.setMaxAllowance(1 ether);
        assertEq(buffer.allowance(), 1 ether);
    }

    function testSetMaxAllowanceRaiseKeepsCurrent() public {
        vm.deal(address(safe), 20 ether);
        buffer.forward();
        vm.warp(block.timestamp + 50);

        vm.prank(address(safe));
        buffer.setMaxAllowance(8 ether);
        assertEq(buffer.allowance(), 2 ether);

        vm.warp(block.timestamp + 25);
        assertEq(buffer.allowance(), 4 ether);

        vm.warp(block.timestamp + 1000);
        assertEq(buffer.allowance(), 8 ether);
    }

    function testSetWindowKeepsAccrued() public {
        vm.deal(address(safe), 20 ether);
        buffer.forward();
        vm.warp(block.timestamp + 50);

        vm.expectEmit(false, false, false, true, address(buffer));
        emit WindowSet(200);
        vm.prank(address(safe));
        buffer.setWindow(200);
        assertEq(buffer.allowance(), 2 ether);

        vm.warp(block.timestamp + 50);
        assertEq(buffer.allowance(), 3 ether);
    }

    function testMaxAllowanceTooHigh() public {
        uint256 tooHigh = uint256(type(uint192).max) + 1;
        vm.expectRevert(SafeEthRateLimitedBuffer.MaxAllowanceTooHigh.selector);
        new SafeEthRateLimitedBuffer(ISafe(address(safe)), pauser, recipient, 10 ether, tooHigh, 100);

        vm.expectRevert(SafeEthRateLimitedBuffer.MaxAllowanceTooHigh.selector);
        vm.prank(address(safe));
        buffer.setMaxAllowance(tooHigh);
        assertEq(buffer.maxAllowance(), 4 ether);
    }

    function testForwardAfterLongWarp() public {
        vm.deal(address(safe), 20 ether);
        buffer.forward();
        assertEq(buffer.allowance(), 0);

        vm.warp(block.timestamp + 100 * 365 days);
        assertEq(buffer.allowance(), 4 ether);
        vm.deal(recipient, 9 ether);
        buffer.forward();
        assertEq(recipient.balance, 10 ether);
        assertEq(buffer.allowance(), 3 ether);

        vm.warp(block.timestamp + 25);
        assertEq(buffer.allowance(), 4 ether);
        vm.deal(recipient, 0);
        buffer.forward();
        assertEq(buffer.allowance(), 0);

        vm.warp(block.timestamp + 50);
        assertEq(buffer.allowance(), 2 ether);
    }

    function testSetWindowZero() public {
        vm.expectRevert(SafeEthRateLimitedBuffer.ZeroWindow.selector);
        vm.prank(address(safe));
        buffer.setWindow(0);
    }

    function testMaxUint192AllowanceDoesNotOverflow() public {
        uint256 max = type(uint192).max;
        buffer = _deploy(recipient, 10 ether, max, 100);
        vm.deal(address(safe), 30 ether);

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
        vm.prank(address(safe));
        buffer.setMaxAllowance(max);
        vm.prank(address(safe));
        buffer.setWindow(200);

        vm.warp(block.timestamp + 1000);
        assertEq(buffer.allowance(), max);
        vm.deal(recipient, 0);
        buffer.forward();
        assertEq(recipient.balance, 10 ether);
        vm.prank(address(safe));
        buffer.setWindow(100);
        vm.prank(address(safe));
        buffer.setMaxAllowance(4 ether);
        assertEq(buffer.allowance(), 4 ether);
    }

    function testFuzzAllowanceMatchesFormula(uint256 max, uint256 window, uint256 spent, uint256 elapsed) public {
        max = bound(max, 0, type(uint192).max);
        window = bound(window, 1, type(uint64).max);
        spent = bound(spent, 0, max);
        elapsed = bound(elapsed, 0, type(uint64).max);
        buffer = _deploy(recipient, type(uint256).max, max, window);
        vm.deal(address(safe), spent);
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
