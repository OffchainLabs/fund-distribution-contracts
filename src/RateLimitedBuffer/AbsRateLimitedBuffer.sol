// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../AbsOwnablePausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract AbsRateLimitedBuffer is AbsOwnablePausable {
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

    constructor(
        address owner_,
        address pauser_,
        address recipient_,
        uint256 target_,
        uint256 maxAllowance_,
        uint256 window_
    ) AbsOwnablePausable(owner_, pauser_) {
        if (window_ == 0) revert ZeroWindow();
        recipient = recipient_;
        targetBalance = target_;
        maxAllowance = maxAllowance_;
        window = window_;
        _setAllowance(maxAllowance_);
    }

    function forward() external whenNotPaused {
        uint256 amount = forwardAmount();
        if (amount > 0) {
            _setAllowance(allowance() - amount);
            _send(amount);
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
        uint256 recipientBalance = _recipientBalance();
        uint256 shortfall = targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
        return _min(_min(shortfall, allowance()), _balance());
    }

    function setRecipient(address recipient_) external onlyOwner {
        recipient = recipient_;
        emit RecipientSet(recipient_);
    }

    function setTarget(uint256 target_) external onlyOwner {
        targetBalance = target_;
        emit TargetSet(target_);
    }

    function setMaxAllowance(uint256 maxAllowance_) external onlyOwner {
        _setAllowance(_min(allowance(), maxAllowance_));
        maxAllowance = maxAllowance_;
        emit MaxAllowanceSet(maxAllowance_);
    }

    function setWindow(uint256 window_) external onlyOwner {
        if (window_ == 0) revert ZeroWindow();
        _setAllowance(allowance());
        window = window_;
        emit WindowSet(window_);
    }

    function _setAllowance(uint256 allowance_) internal {
        storedAllowance = allowance_;
        lastUpdate = block.timestamp;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _balance() internal view virtual returns (uint256);

    function _recipientBalance() internal view virtual returns (uint256);

    function _send(uint256 amount) internal virtual;
}
