// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @notice Accepts funds after burning `amount` gas.
/// @dev Fails only when it is given less gas than it burns.
contract GasBurner {
    uint256 immutable amount;

    constructor(uint256 _amount) {
        amount = _amount;
    }

    receive() external payable {
        uint256 start = gasleft();
        while (start - gasleft() < amount) {}
    }
}
