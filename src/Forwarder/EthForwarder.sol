// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../AbsOwnablePausable.sol";

contract EthForwarder is AbsOwnablePausable {
    address public recipient;
    address public remainder;
    uint256 public targetBalance;

    event Forwarded(uint256 toRecipient, uint256 toRemainder);
    event RecipientSet(address recipient);
    event RemainderSet(address remainder);
    event TargetSet(uint256 target);

    error TransferFailed();

    constructor(address _owner, address _pauser, address _recipient, address _remainder, uint256 _target)
        AbsOwnablePausable(_owner, _pauser)
    {
        recipient = _recipient;
        remainder = _remainder;
        targetBalance = _target;
    }

    receive() external payable {}

    function forward() external whenNotPaused {
        (uint256 toRecipient, uint256 toRemainder) = forwardAmounts();
        if (toRecipient > 0) _send(recipient, toRecipient);
        if (toRemainder > 0) _send(remainder, toRemainder);
        emit Forwarded(toRecipient, toRemainder);
    }

    function forwardAmounts() public view returns (uint256 toRecipient, uint256 toRemainder) {
        uint256 balance = address(this).balance;
        uint256 recipientBalance = recipient.balance;
        uint256 shortfall = targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
        toRecipient = shortfall < balance ? shortfall : balance;
        toRemainder = balance - toRecipient;
    }

    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
        emit RecipientSet(_recipient);
    }

    function setRemainder(address _remainder) external onlyOwner {
        remainder = _remainder;
        emit RemainderSet(_remainder);
    }

    function setTarget(uint256 _target) external onlyOwner {
        targetBalance = _target;
        emit TargetSet(_target);
    }

    function _send(address to, uint256 amount) private {
        (bool success,) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
