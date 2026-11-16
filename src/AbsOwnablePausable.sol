// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract AbsOwnablePausable is Ownable, Pausable {
    address public pauser;

    event PauserSet(address pauser);

    error NotPauser();

    constructor(address owner_, address pauser_) {
        _transferOwnership(owner_);
        pauser = pauser_;
    }

    function pause() external {
        if (msg.sender != pauser && msg.sender != owner()) revert NotPauser();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setPauser(address pauser_) external onlyOwner {
        pauser = pauser_;
        emit PauserSet(pauser_);
    }
}
