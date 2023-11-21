// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

contract DistributionInterval {
    uint256 public nextDistribution;
    uint256 immutable minDistributionIntervalSeconds;

    constructor(uint256 _minDistributionIntervalSeconds) {
        minDistributionIntervalSeconds = _minDistributionIntervalSeconds;
    }

    function timeToNextDistribution() public view returns (uint256) {
        return
            block.timestamp >= nextDistribution
                ? 0
                : nextDistribution - block.timestamp;
    }

    function canDistribute() public view returns (bool) {
        return timeToNextDistribution() == 0;
    }

    function _updateDistribution() internal {
        nextDistribution = block.timestamp + minDistributionIntervalSeconds;
    }
}
