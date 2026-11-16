// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsRateLimitedBuffer.sol";

contract EthRateLimitedBuffer is AbsRateLimitedBuffer {
    error TransferFailed();

    constructor(
        address owner_,
        address pauser_,
        address recipient_,
        uint256 target_,
        uint256 maxAllowance_,
        uint256 window_
    ) AbsRateLimitedBuffer(owner_, pauser_, recipient_, target_, maxAllowance_, window_) {}

    receive() external payable {}

    function _balance() internal view override returns (uint256) {
        return address(this).balance;
    }

    function _send(uint256 amount) internal override {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
