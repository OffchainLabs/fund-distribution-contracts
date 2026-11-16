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
        ISafe _safe,
        address _owner,
        address _pauser,
        address _recipient,
        uint256 _target,
        uint256 _maxAllowance,
        uint256 _window
    ) AbsRateLimitedBuffer(_owner, _pauser, _recipient, _target, _maxAllowance, _window) {
        safe = _safe;
    }

    function _balance() internal view override returns (uint256) {
        return address(safe).balance;
    }

    function _send(uint256 amount) internal override {
        if (!safe.execTransactionFromModule(recipient, amount, "", 0)) revert SafeTransferFailed();
    }
}
