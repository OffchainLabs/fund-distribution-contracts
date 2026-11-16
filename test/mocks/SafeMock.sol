// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract SafeMock {
    mapping(address => bool) public modules;

    receive() external payable {}

    function enableModule(address module) external {
        modules[module] = true;
    }

    function execTransactionFromModule(address to, uint256 value, bytes memory data, uint8 operation)
        external
        returns (bool success)
    {
        require(modules[msg.sender], "GS104");
        require(operation == 0, "only call");
        (success,) = to.call{value: value}(data);
    }
}
