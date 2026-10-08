// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../src/WethUnwrapper.sol";
import "../mocks/WethMock.sol";
import "../mocks/Empty.sol";

import "forge-std/Test.sol";

contract WethUnwrapperTest is Test {
    WethMock weth;
    WethUnwrapper unwrapper;
    address recipient = address(0x404040);

    event Sent(uint256 amount);

    function setUp() public {
        weth = new WethMock();
        unwrapper = new WethUnwrapper(IWETH(address(weth)), recipient);
    }

    function testUnwrap() public {
        weth.deposit{value: 3 ether}();
        weth.transfer(address(unwrapper), 3 ether);
        vm.deal(address(unwrapper), 1 ether);

        vm.expectEmit(false, false, false, true, address(unwrapper));
        emit Sent(4 ether);
        unwrapper.unwrap();

        assertEq(recipient.balance, 4 ether);
        assertEq(weth.balanceOf(address(unwrapper)), 0);
        assertEq(address(unwrapper).balance, 0);
    }

    function testUnwrapZero() public {
        vm.expectEmit(false, false, false, true, address(unwrapper));
        emit Sent(0);
        unwrapper.unwrap();

        assertEq(recipient.balance, 0);
    }

    function testUnwrapRecipientReverts() public {
        unwrapper = new WethUnwrapper(IWETH(address(weth)), address(new Empty()));
        vm.deal(address(unwrapper), 1 ether);

        vm.expectRevert("send failed");
        unwrapper.unwrap();
    }
}
