// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../AbsOwnablePausable.sol";

abstract contract AbsForwarder is AbsOwnablePausable {
    address public recipient;
    address public remainder;
    uint256 public targetBalance;

    event Forwarded(uint256 toRecipient, uint256 toRemainder);
    event RecipientSet(address recipient);
    event RemainderSet(address remainder);
    event TargetSet(uint256 target);

    constructor(address owner_, address pauser_, address recipient_, address remainder_, uint256 target_)
        AbsOwnablePausable(owner_, pauser_)
    {
        recipient = recipient_;
        remainder = remainder_;
        targetBalance = target_;
    }

    function forward() external whenNotPaused {
        (uint256 toRecipient, uint256 toRemainder) = forwardAmounts();
        if (toRecipient > 0) _send(recipient, toRecipient);
        if (toRemainder > 0) _send(remainder, toRemainder);
        emit Forwarded(toRecipient, toRemainder);
    }

    function forwardAmounts() public view returns (uint256 toRecipient, uint256 toRemainder) {
        uint256 balance = _balance();
        uint256 recipientBalance = _recipientBalance();
        uint256 shortfall = targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
        toRecipient = shortfall < balance ? shortfall : balance;
        toRemainder = balance - toRecipient;
    }

    function setRecipient(address recipient_) external onlyOwner {
        recipient = recipient_;
        emit RecipientSet(recipient_);
    }

    function setRemainder(address remainder_) external onlyOwner {
        remainder = remainder_;
        emit RemainderSet(remainder_);
    }

    function setTarget(uint256 target_) external onlyOwner {
        targetBalance = target_;
        emit TargetSet(target_);
    }

    function _balance() internal view virtual returns (uint256);

    function _recipientBalance() internal view virtual returns (uint256);

    function _send(address to, uint256 amount) internal virtual;
}
