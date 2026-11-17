// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EthForwarder is Ownable, Pausable {
    address public pauser;
    address public recipient;
    uint256 public targetBalance;
    address public remainder;

    event Forwarded(uint256 toRecipient, uint256 toRemainder);
    event PauserSet(address pauser);
    event RecipientSet(address recipient);
    event RemainderSet(address remainder);
    event TargetBalanceSet(uint256 targetBalance);

    error NotPauser();
    error TransferFailed();

    constructor(address _owner, address _pauser, address _recipient, address _remainder, uint256 _targetBalance) {
        _transferOwnership(_owner);
        pauser = _pauser;
        recipient = _recipient;
        targetBalance = _targetBalance;
        remainder = _remainder;
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

    function pause() external {
        if (msg.sender != pauser && msg.sender != owner()) revert NotPauser();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setPauser(address _pauser) external onlyOwner {
        pauser = _pauser;
        emit PauserSet(_pauser);
    }

    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
        emit RecipientSet(_recipient);
    }

    function setRemainder(address _remainder) external onlyOwner {
        remainder = _remainder;
        emit RemainderSet(_remainder);
    }

    function setTargetBalance(uint256 _targetBalance) external onlyOwner {
        targetBalance = _targetBalance;
        emit TargetBalanceSet(_targetBalance);
    }

    function _send(address _to, uint256 _amount) internal {
        (bool success,) = _to.call{value: _amount}("");
        if (!success) revert TransferFailed();
    }
}
