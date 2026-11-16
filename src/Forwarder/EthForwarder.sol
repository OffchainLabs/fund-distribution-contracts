// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsForwarder.sol";

contract EthForwarder is AbsForwarder {
    error TransferFailed();

    constructor(address owner_, address recipient_, address remainder_, uint256 target_)
        AbsForwarder(owner_, recipient_, remainder_, target_)
    {}

    receive() external payable {}

    function _balance() internal view override returns (uint256) {
        return address(this).balance;
    }

    function _recipientBalance() internal view override returns (uint256) {
        return recipient.balance;
    }

    function _send(address to, uint256 amount) internal override {
        (bool success,) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
