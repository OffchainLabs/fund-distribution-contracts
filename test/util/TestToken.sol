// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(address initialWhale, uint256 initialSuply) ERC20("TestToken", "TEST") {
        _mint(initialWhale, initialSuply);
    }
}
