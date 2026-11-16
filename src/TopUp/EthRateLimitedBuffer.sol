// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsOwnablePausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract EthRateLimitedBuffer is AbsOwnablePausable {
    address public recipient;
    uint256 public targetBalance;
    uint256 public maxAllowance;
    uint256 public window;

    uint256 internal storedAllowance;
    uint256 internal lastUpdate;

    event Forwarded(uint256 amount);
    event RecipientSet(address recipient);
    event TargetSet(uint256 target);
    event MaxAllowanceSet(uint256 maxAllowance);
    event WindowSet(uint256 window);

    error ZeroWindow();
    error TransferFailed();

    constructor(
        address _owner,
        address _pauser,
        address _recipient,
        uint256 _target,
        uint256 _maxAllowance,
        uint256 _window
    ) AbsOwnablePausable(_owner, _pauser) {
        if (_window == 0) revert ZeroWindow();
        recipient = _recipient;
        targetBalance = _target;
        maxAllowance = _maxAllowance;
        window = _window;
        _setAllowance(_maxAllowance);
    }

    receive() external payable {}

    function forward() external whenNotPaused {
        uint256 amount = forwardAmount();
        if (amount > 0) {
            _setAllowance(allowance() - amount);
            (bool success,) = recipient.call{value: amount}("");
            if (!success) revert TransferFailed();
        }
        emit Forwarded(amount);
    }

    function allowance() public view returns (uint256) {
        uint256 elapsed = block.timestamp - lastUpdate;
        if (elapsed >= window) return maxAllowance;
        uint256 refill = Math.mulDiv(maxAllowance, elapsed, window);
        if (refill >= maxAllowance - storedAllowance) return maxAllowance;
        return storedAllowance + refill;
    }

    function forwardAmount() public view returns (uint256) {
        uint256 recipientBalance = recipient.balance;
        uint256 shortfall = targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
        return _min(_min(shortfall, allowance()), address(this).balance);
    }

    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
        emit RecipientSet(_recipient);
    }

    function setTarget(uint256 _target) external onlyOwner {
        targetBalance = _target;
        emit TargetSet(_target);
    }

    function setMaxAllowance(uint256 _maxAllowance) external onlyOwner {
        _setAllowance(_min(allowance(), _maxAllowance));
        maxAllowance = _maxAllowance;
        emit MaxAllowanceSet(_maxAllowance);
    }

    function setWindow(uint256 _window) external onlyOwner {
        if (_window == 0) revert ZeroWindow();
        _setAllowance(allowance());
        window = _window;
        emit WindowSet(_window);
    }

    function _setAllowance(uint256 _allowance) internal {
        storedAllowance = _allowance;
        lastUpdate = block.timestamp;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
