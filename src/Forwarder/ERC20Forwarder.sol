// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsForwarder.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Forwarder is AbsForwarder {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    constructor(IERC20 token_, address owner_, address recipient_, address remainder_, uint256 target_)
        AbsForwarder(owner_, recipient_, remainder_, target_)
    {
        token = token_;
    }

    function _balance() internal view override returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _recipientBalance() internal view override returns (uint256) {
        return token.balanceOf(recipient);
    }

    function _send(address to, uint256 amount) internal override {
        token.safeTransfer(to, amount);
    }
}
