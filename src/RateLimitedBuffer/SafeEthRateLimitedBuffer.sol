// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsRateLimitedBuffer.sol";

interface ISafe {
    function execTransactionFromModule(address to, uint256 value, bytes memory data, uint8 operation)
        external
        returns (bool success);
}

/// @notice Forwards ETH held by a Safe. This contract must be enabled as a module on the Safe.
contract SafeEthRateLimitedBuffer is AbsRateLimitedBuffer {
    ISafe public immutable safe;

    error SafeTransferFailed();

    constructor(
        ISafe safe_,
        address owner_,
        address recipient_,
        uint256 target_,
        uint256 maxAllowance_,
        uint256 window_
    ) AbsRateLimitedBuffer(owner_, recipient_, target_, maxAllowance_, window_) {
        safe = safe_;
    }

    function _balance() internal view override returns (uint256) {
        return address(safe).balance;
    }

    function _recipientBalance() internal view override returns (uint256) {
        return recipient.balance;
    }

    function _send(uint256 amount) internal override {
        if (!safe.execTransactionFromModule(recipient, amount, "", 0)) revert SafeTransferFailed();
    }
}
