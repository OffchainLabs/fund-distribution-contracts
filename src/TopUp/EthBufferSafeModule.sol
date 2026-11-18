// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface ISafe {
    function execTransactionFromModule(address to, uint256 value, bytes memory data, uint8 operation)
        external
        returns (bool success);
}

/// @notice Forwards ETH held by a Safe. This contract must be enabled as a module on the Safe.
contract EthBufferSafeModule is Pausable {
    /// @notice Safe that holds the ETH and administers this module.
    ISafe public immutable safe;
    /// @notice Address allowed to pause alongside the Safe.
    address public pauser;
    /// @notice Address whose balance is topped up.
    address public recipient;
    /// @notice Balance the recipient is topped up to.
    uint256 public targetBalance;
    /// @notice Maximum ETH forwardable per window.
    uint256 public maxAllowance;
    /// @notice Seconds for the allowance to fully refill.
    uint256 public window;

    /// @notice Allowance as of lastUpdate, before refill.
    uint192 public storedAllowance;
    /// @notice Timestamp of the last allowance checkpoint.
    uint64 public lastUpdate;

    event Forwarded(uint256 amount);
    event PauserSet(address pauser);
    event RecipientSet(address recipient);
    event TargetBalanceSet(uint256 targetBalance);
    event MaxAllowanceSet(uint256 maxAllowance);
    event WindowSet(uint256 window);

    error NotSafe();
    error NotPauser();
    error ZeroWindow();
    error MaxAllowanceTooHigh();
    error SafeTransferFailed();

    modifier onlySafe() {
        if (msg.sender != address(safe)) revert NotSafe();
        _;
    }

    constructor(
        ISafe _safe,
        address _pauser,
        address _recipient,
        uint256 _targetBalance,
        uint256 _maxAllowance,
        uint256 _window
    ) {
        if (_window == 0) revert ZeroWindow();
        if (_maxAllowance > type(uint192).max) revert MaxAllowanceTooHigh();
        safe = _safe;
        pauser = _pauser;
        recipient = _recipient;
        targetBalance = _targetBalance;
        maxAllowance = _maxAllowance;
        window = _window;
        _setAllowance(_maxAllowance);
    }

    /// @notice Sends ETH from the Safe to the recipient to cover its shortfall, limited by the allowance.
    function forward() external whenNotPaused {
        uint256 _allowance = allowance();
        uint256 amount = _forwardAmount(_allowance);
        if (amount > 0) {
            _setAllowance(_allowance - amount);
            if (!safe.execTransactionFromModule(recipient, amount, "", 0)) revert SafeTransferFailed();
        }
        emit Forwarded(amount);
    }

    /// @notice Returns the ETH currently forwardable under the rate limit.
    function allowance() public view returns (uint256) {
        uint256 elapsed = block.timestamp - lastUpdate;
        if (elapsed >= window) return maxAllowance;
        uint256 refill = Math.mulDiv(maxAllowance, elapsed, window);
        if (refill >= maxAllowance - storedAllowance) return maxAllowance;
        return storedAllowance + refill;
    }

    /// @notice Returns the amount the next forward call would send.
    function forwardAmount() public view returns (uint256) {
        return _forwardAmount(allowance());
    }

    /// @notice Pauses forwarding; callable by the pauser or the Safe.
    function pause() external {
        if (msg.sender != pauser && msg.sender != address(safe)) revert NotPauser();
        _pause();
    }

    /// @notice Resumes forwarding; callable only by the Safe.
    function unpause() external onlySafe {
        _unpause();
    }

    /// @notice Sets the pauser.
    /// @param _pauser New pauser address.
    function setPauser(address _pauser) external onlySafe {
        pauser = _pauser;
        emit PauserSet(_pauser);
    }

    /// @notice Sets the recipient.
    /// @param _recipient New recipient address.
    function setRecipient(address _recipient) external onlySafe {
        recipient = _recipient;
        emit RecipientSet(_recipient);
    }

    /// @notice Sets the recipient's target balance.
    /// @param _targetBalance New target balance in wei.
    function setTargetBalance(uint256 _targetBalance) external onlySafe {
        targetBalance = _targetBalance;
        emit TargetBalanceSet(_targetBalance);
    }

    /// @notice Sets the max allowance, capping the current allowance to it.
    /// @param _maxAllowance New maximum ETH forwardable per window.
    function setMaxAllowance(uint256 _maxAllowance) external onlySafe {
        if (_maxAllowance > type(uint192).max) revert MaxAllowanceTooHigh();
        _setAllowance(Math.min(allowance(), _maxAllowance));
        maxAllowance = _maxAllowance;
        emit MaxAllowanceSet(_maxAllowance);
    }

    /// @notice Sets the refill window, preserving the current allowance.
    /// @param _window New refill window in seconds.
    function setWindow(uint256 _window) external onlySafe {
        if (_window == 0) revert ZeroWindow();
        _setAllowance(allowance());
        window = _window;
        emit WindowSet(_window);
    }

    /// @dev Returns the minimum of the recipient's shortfall, the allowance, and the Safe's balance.
    /// @param _allowance Allowance to cap the amount by.
    function _forwardAmount(uint256 _allowance) internal view returns (uint256) {
        uint256 recipientBalance = recipient.balance;
        uint256 shortfall = targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
        return Math.min(Math.min(shortfall, _allowance), address(safe).balance);
    }

    /// @dev Checkpoints the allowance at the current timestamp.
    /// @param _allowance Allowance to store.
    function _setAllowance(uint256 _allowance) internal {
        storedAllowance = uint192(_allowance);
        lastUpdate = uint64(block.timestamp);
    }
}
