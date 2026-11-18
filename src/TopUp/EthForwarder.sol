// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @notice Tops up a recipient to a target balance from received ETH and sends the rest to a remainder address.
contract EthForwarder is Ownable, Pausable {
    /// @notice Address allowed to pause alongside the owner.
    address public pauser;
    /// @notice Address whose balance is topped up.
    address public recipient;
    /// @notice Balance the recipient is topped up to.
    uint256 public targetBalance;
    /// @notice Address that receives ETH beyond the recipient's shortfall.
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

    /// @notice Sends the recipient's shortfall to the recipient and the rest of the balance to the remainder.
    function forward() external whenNotPaused {
        (uint256 toRecipient, uint256 toRemainder) = forwardAmounts();
        if (toRecipient > 0) _send(recipient, toRecipient);
        if (toRemainder > 0) _send(remainder, toRemainder);
        emit Forwarded(toRecipient, toRemainder);
    }

    /// @notice Returns the amounts the next forward call would send to the recipient and remainder.
    function forwardAmounts() public view returns (uint256 toRecipient, uint256 toRemainder) {
        uint256 balance = address(this).balance;
        uint256 recipientBalance = recipient.balance;
        uint256 shortfall = targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
        toRecipient = shortfall < balance ? shortfall : balance;
        toRemainder = balance - toRecipient;
    }

    /// @notice Pauses forwarding; callable by the pauser or the owner.
    function pause() external {
        if (msg.sender != pauser && msg.sender != owner()) revert NotPauser();
        _pause();
    }

    /// @notice Resumes forwarding; callable only by the owner.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets the pauser.
    /// @param _pauser New pauser address.
    function setPauser(address _pauser) external onlyOwner {
        pauser = _pauser;
        emit PauserSet(_pauser);
    }

    /// @notice Sets the recipient.
    /// @param _recipient New recipient address.
    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
        emit RecipientSet(_recipient);
    }

    /// @notice Sets the remainder address.
    /// @param _remainder New remainder address.
    function setRemainder(address _remainder) external onlyOwner {
        remainder = _remainder;
        emit RemainderSet(_remainder);
    }

    /// @notice Sets the recipient's target balance.
    /// @param _targetBalance New target balance in wei.
    function setTargetBalance(uint256 _targetBalance) external onlyOwner {
        targetBalance = _targetBalance;
        emit TargetBalanceSet(_targetBalance);
    }

    /// @dev Sends ETH via call and reverts on failure.
    /// @param _to Address to send to.
    /// @param _amount Amount of wei to send.
    function _send(address _to, uint256 _amount) internal {
        (bool success,) = _to.call{value: _amount}("");
        if (!success) revert TransferFailed();
    }
}
