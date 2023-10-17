// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IArbSys {
    function withdrawEth(
        address destination
    ) external payable returns (uint256);
}

contract RewardReceiver {
    address immutable parentChainTarget;

    constructor(address _parentChainTarget) {
        parentChainTarget = _parentChainTarget;
    }

    receive() external payable {
        IArbSys(address(100)).withdrawEth{value: address(this).balance}(
            parentChainTarget
        );
    }
}
