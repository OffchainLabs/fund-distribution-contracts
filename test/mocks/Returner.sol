// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @notice Accepts funds and returns `size` bytes of returndata.
/// @dev The memory expansion is paid out of the gas it is given.
contract Returner {
    uint256 immutable size;

    constructor(uint256 _size) {
        size = _size;
    }

    receive() external payable {
        uint256 s = size;
        assembly {
            return(0, s)
        }
    }
}
