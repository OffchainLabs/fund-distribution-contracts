// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsTopUp.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract EthRateLimitedBuffer is AbsTopUp {
    uint256 public maxAllowance;
    uint256 public window;

    uint192 internal storedAllowance;
    uint64 internal lastUpdate;

    event Forwarded(uint256 amount);
    event MaxAllowanceSet(uint256 maxAllowance);
    event WindowSet(uint256 window);

    error ZeroWindow();
    error MaxAllowanceTooHigh();

    constructor(
        address _owner,
        address _pauser,
        address _recipient,
        uint256 _targetBalance,
        uint256 _maxAllowance,
        uint256 _window
    ) AbsTopUp(_owner, _pauser, _recipient, _targetBalance) {
        if (_window == 0) revert ZeroWindow();
        if (_maxAllowance > type(uint192).max) revert MaxAllowanceTooHigh();
        maxAllowance = _maxAllowance;
        window = _window;
        _setAllowance(_maxAllowance);
    }

    function forward() external whenNotPaused {
        uint256 _allowance = allowance();
        uint256 amount = _forwardAmount(_allowance);
        if (amount > 0) {
            _setAllowance(_allowance - amount);
            _send(recipient, amount);
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

    function setMaxAllowance(uint256 _maxAllowance) external onlyOwner {
        if (_maxAllowance > type(uint192).max) revert MaxAllowanceTooHigh();
        _setAllowance(Math.min(allowance(), _maxAllowance));
        maxAllowance = _maxAllowance;
        emit MaxAllowanceSet(_maxAllowance);
    }

    function setWindow(uint256 _window) external onlyOwner {
        if (_window == 0) revert ZeroWindow();
        _setAllowance(allowance());
        window = _window;
        emit WindowSet(_window);
    }

    function _forwardAmount(uint256 _allowance) internal view returns (uint256) {
        return Math.min(Math.min(_shortfall(), _allowance), address(this).balance);
    }

    function _setAllowance(uint256 _allowance) internal {
        storedAllowance = uint192(_allowance);
        lastUpdate = uint64(block.timestamp);
    }
}
