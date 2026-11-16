// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract AbsOwnablePausable is Ownable, Pausable {
    address public pauser;

    event PauserSet(address pauser);

    error NotPauser();

    constructor(address _owner, address _pauser) {
        _transferOwnership(_owner);
        pauser = _pauser;
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
}
