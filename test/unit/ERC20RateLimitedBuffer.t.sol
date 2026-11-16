// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/RateLimitedBuffer/ERC20RateLimitedBuffer.sol";
import "../mocks/TestToken.sol";

import "forge-std/Test.sol";

contract ERC20RateLimitedBufferTest is Test {
    TestToken token;
    ERC20RateLimitedBuffer buffer;
    address owner = address(0x1111);
    address recipient = address(0x2222);

    function setUp() public {
        token = new TestToken(100 ether);
        buffer = new ERC20RateLimitedBuffer(token, owner, recipient, 10 ether, 4 ether, 100);
    }

    function testConstructor() public {
        assertEq(address(buffer.token()), address(token));
        assertEq(buffer.owner(), owner);
    }

    function testForwardUsesTokenBalances() public {
        token.transfer(address(buffer), 20 ether);
        token.transfer(recipient, 9 ether);
        vm.deal(address(buffer), 20 ether);
        vm.deal(recipient, 20 ether);

        buffer.forward();

        assertEq(token.balanceOf(recipient), 10 ether);
        assertEq(token.balanceOf(address(buffer)), 19 ether);
        assertEq(recipient.balance, 20 ether);
    }

    function testForwardLimitedByTokenFunds() public {
        token.transfer(address(buffer), 1 ether);
        vm.deal(address(buffer), 20 ether);

        buffer.forward();

        assertEq(token.balanceOf(recipient), 1 ether);
    }
}
