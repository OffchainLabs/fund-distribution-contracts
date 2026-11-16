// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./AbsTopUp.sol";

contract EthForwarder is AbsTopUp {
    address public remainder;

    event Forwarded(uint256 toRecipient, uint256 toRemainder);
    event RemainderSet(address remainder);

    constructor(address _owner, address _pauser, address _recipient, address _remainder, uint256 _targetBalance)
        AbsTopUp(_owner, _pauser, _recipient, _targetBalance)
    {
        remainder = _remainder;
    }

    function forward() external whenNotPaused {
        (uint256 toRecipient, uint256 toRemainder) = forwardAmounts();
        if (toRecipient > 0) _send(recipient, toRecipient);
        if (toRemainder > 0) _send(remainder, toRemainder);
        emit Forwarded(toRecipient, toRemainder);
    }

    function forwardAmounts() public view returns (uint256 toRecipient, uint256 toRemainder) {
        uint256 balance = address(this).balance;
        uint256 shortfall = _shortfall();
        toRecipient = shortfall < balance ? shortfall : balance;
        toRemainder = balance - toRecipient;
    }

    function setRemainder(address _remainder) external onlyOwner {
        remainder = _remainder;
        emit RemainderSet(_remainder);
    }
}
