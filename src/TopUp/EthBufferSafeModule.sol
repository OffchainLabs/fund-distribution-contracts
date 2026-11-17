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
    ISafe public immutable safe;
    address public pauser;
    address public recipient;
    uint256 public targetBalance;
    uint256 public maxAllowance;
    uint256 public window;

    uint192 internal storedAllowance;
    uint64 internal lastUpdate;

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

    function forward() external whenNotPaused {
        uint256 _allowance = allowance();
        uint256 amount = _forwardAmount(_allowance);
        if (amount > 0) {
            _setAllowance(_allowance - amount);
            if (!safe.execTransactionFromModule(recipient, amount, "", 0)) revert SafeTransferFailed();
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
        return _forwardAmount(allowance());
    }

    function pause() external {
        if (msg.sender != pauser && msg.sender != address(safe)) revert NotPauser();
        _pause();
    }

    function unpause() external onlySafe {
        _unpause();
    }

    function setPauser(address _pauser) external onlySafe {
        pauser = _pauser;
        emit PauserSet(_pauser);
    }

    function setRecipient(address _recipient) external onlySafe {
        recipient = _recipient;
        emit RecipientSet(_recipient);
    }

    function setTargetBalance(uint256 _targetBalance) external onlySafe {
        targetBalance = _targetBalance;
        emit TargetBalanceSet(_targetBalance);
    }

    function setMaxAllowance(uint256 _maxAllowance) external onlySafe {
        if (_maxAllowance > type(uint192).max) revert MaxAllowanceTooHigh();
        _setAllowance(Math.min(allowance(), _maxAllowance));
        maxAllowance = _maxAllowance;
        emit MaxAllowanceSet(_maxAllowance);
    }

    function setWindow(uint256 _window) external onlySafe {
        if (_window == 0) revert ZeroWindow();
        _setAllowance(allowance());
        window = _window;
        emit WindowSet(_window);
    }

    function _forwardAmount(uint256 _allowance) internal view returns (uint256) {
        uint256 recipientBalance = recipient.balance;
        uint256 shortfall = targetBalance > recipientBalance ? targetBalance - recipientBalance : 0;
        return Math.min(Math.min(shortfall, _allowance), address(safe).balance);
    }

    function _setAllowance(uint256 _allowance) internal {
        storedAllowance = uint192(_allowance);
        lastUpdate = uint64(block.timestamp);
    }
}
