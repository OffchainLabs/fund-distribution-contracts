// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/Forwarder/ERC20Forwarder.sol";
import "../mocks/TestToken.sol";

import "forge-std/Test.sol";

contract ERC20ForwarderTest is Test {
    TestToken token;
    ERC20Forwarder forwarder;
    address owner = address(0x1111);
    address recipient = address(0x2222);
    address remainder = address(0x3333);

    function setUp() public {
        token = new TestToken(100 ether);
        forwarder = new ERC20Forwarder(token, owner, recipient, remainder, 10 ether);
    }

    function testConstructor() public {
        assertEq(address(forwarder.token()), address(token));
        assertEq(forwarder.owner(), owner);
        assertEq(forwarder.recipient(), recipient);
        assertEq(forwarder.remainder(), remainder);
        assertEq(forwarder.target(), 10 ether);
    }

    function testForwardUsesTokenBalances() public {
        token.transfer(address(forwarder), 20 ether);
        token.transfer(recipient, 3 ether);
        vm.deal(address(forwarder), 20 ether);
        vm.deal(recipient, 20 ether);

        (uint256 toRecipient, uint256 toRemainder) = forwarder.forwardAmounts();
        assertEq(toRecipient, 7 ether);
        assertEq(toRemainder, 13 ether);

        forwarder.forward();

        assertEq(token.balanceOf(recipient), 10 ether);
        assertEq(token.balanceOf(remainder), 13 ether);
        assertEq(token.balanceOf(address(forwarder)), 0);
        assertEq(address(forwarder).balance, 20 ether);
        assertEq(recipient.balance, 20 ether);
    }

    function testForwardTransferReturnsFalse() public {
        token.transfer(address(forwarder), 20 ether);
        vm.mockCall(address(token), abi.encodeCall(IERC20.transfer, (recipient, 10 ether)), abi.encode(false));

        vm.expectRevert("SafeERC20: ERC20 operation did not succeed");
        forwarder.forward();
    }
}
