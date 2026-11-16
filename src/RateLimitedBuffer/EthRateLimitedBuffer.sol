// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsRateLimitedBuffer.sol";

contract EthRateLimitedBuffer is AbsRateLimitedBuffer {
    error TransferFailed();

    constructor(
        address _owner,
        address _pauser,
        address _recipient,
        uint256 _target,
        uint256 _maxAllowance,
        uint256 _window
    ) AbsRateLimitedBuffer(_owner, _pauser, _recipient, _target, _maxAllowance, _window) {}

    receive() external payable {}

    function _balance() internal view override returns (uint256) {
        return address(this).balance;
    }

    function _send(uint256 amount) internal override {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
