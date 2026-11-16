// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract AbsTopUp is Ownable, Pausable {
    address public pauser;
    address public recipient;
    uint256 public targetBalance;

    event PauserSet(address pauser);
    event RecipientSet(address recipient);
    event TargetSet(uint256 target);

    error NotPauser();
    error TransferFailed();

    constructor(address _owner, address _pauser, address _recipient, uint256 _target) {
        _transferOwnership(_owner);
        pauser = _pauser;
        recipient = _recipient;
        targetBalance = _target;
    }

    receive() external payable {}

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

    function setTarget(uint256 _target) external onlyOwner {
        targetBalance = _target;
        emit TargetSet(_target);
    }

    function _shortfall() internal view returns (uint256) {
        uint256 recipientBalance = recipient.balance;
        return targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
    }

    function _send(address _to, uint256 _amount) internal {
        (bool success,) = _to.call{value: _amount}("");
        if (!success) revert TransferFailed();
    }
}
