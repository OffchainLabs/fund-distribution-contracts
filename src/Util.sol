// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

uint256 constant BASIS_POINTS = 10000;

// utility free functions

/// @notice sequentially hashes an array of addresses
/// @param addresses array of addresses to be hashed
function hashAddresses(address[] memory addresses) pure returns (bytes32 res) {
    assembly ("memory-safe") {
        // same as keccak256(abi.encodePacked(addresses))
        // save gas since the array is already in the memory
        // we skip the first 32 bytes (length) and hash the next length * 32 bytes
        res := keccak256(add(addresses, 32), mul(mload(addresses), 32))
    }
}

/// @notice sequentially hashes an array of weights
/// @param weights array of weights to be hashed
function hashWeights(uint256[] memory weights) pure returns (bytes32 res) {
    assembly ("memory-safe") {
        // same as keccak256(abi.encodePacked(weights))
        // save gas since the array is already in the memory
        // we skip the first 32 bytes (length) and hash the next length * 32 bytes
        res := keccak256(add(weights, 32), mul(mload(weights), 32))
    }
}

/// @notice increments an integer without checking for overflows
/// @dev from https://github.com/ethereum/solidity/issues/11721#issuecomment-890917517
function uncheckedInc(uint256 x) pure returns (uint256) {
    unchecked {
        return x + 1;
    }
}
