// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract ArbSysMock {
    event ArbSysL2ToL1Tx(address from, address to, uint256 value, bytes indexed data);

    uint256 public counter;

    function withdrawEth(address destination) external payable returns (uint256 exitNum) {
        exitNum = counter;
        counter = exitNum + 1;
        emit ArbSysL2ToL1Tx(msg.sender, destination, msg.value, "");
        return exitNum;
    }

    function arbOSVersion() external pure returns (uint256) {
        return 1;
    }
}
