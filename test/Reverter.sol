// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

contract Reverter is Test {
    receive() external payable {
        // emit log_named_uint("gas left initially in reverter", gasleft());
        while (gasleft() > 0) {}
        revert("should have reverted");
    }
}
