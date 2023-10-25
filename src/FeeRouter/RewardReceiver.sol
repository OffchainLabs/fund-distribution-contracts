// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IArbSys {
    function withdrawEth(
        address destination
    ) external payable returns (uint256);
}

contract RewardReceiver {
    address immutable parentChainTarget;
    uint256 immutable minDistributionIntervalSeconds;
    uint256 public nextDistribution;

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds
    ) {
        parentChainTarget = _parentChainTarget;
        minDistributionIntervalSeconds = _minDistributionIntervalSeconds;
    }

    receive() external payable {
        // if distributing too soon, skip withdrawal (but don't revert)
        if (block.timestamp >= nextDistribution) {
            nextDistribution = block.timestamp + minDistributionIntervalSeconds;
            IArbSys(address(100)).withdrawEth{value: address(this).balance}(
                parentChainTarget
            );
        }
    }
}
