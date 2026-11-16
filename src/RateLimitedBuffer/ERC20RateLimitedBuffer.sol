// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsRateLimitedBuffer.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20RateLimitedBuffer is AbsRateLimitedBuffer {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    constructor(
        IERC20 token_,
        address owner_,
        address recipient_,
        uint256 target_,
        uint256 maxAllowance_,
        uint256 window_
    ) AbsRateLimitedBuffer(owner_, recipient_, target_, maxAllowance_, window_) {
        token = token_;
    }

    function _balance() internal view override returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _recipientBalance() internal view override returns (uint256) {
        return token.balanceOf(recipient);
    }

    function _send(uint256 amount) internal override {
        token.safeTransfer(recipient, amount);
    }
}
