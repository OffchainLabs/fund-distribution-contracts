// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

abstract contract DistributionInterval {
    address public constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    mapping(address => uint256) public nextDistributions;
    uint256 immutable minDistributionIntervalSeconds;

    error DistributionTooSoon(uint256 currentTimestamp, uint256 distributionTimestamp);

    constructor(uint256 _minDistributionIntervalSeconds) {
        minDistributionIntervalSeconds = _minDistributionIntervalSeconds;
    }

    function timeToNextDistribution(address _erc20orNative) public view returns (uint256) {
        uint256 nextDistribution = nextDistributions[_erc20orNative];
        return block.timestamp >= nextDistribution ? 0 : nextDistribution - block.timestamp;
    }

    function canDistribute(address _erc20orNative) public view returns (bool) {
        return timeToNextDistribution(_erc20orNative) == 0;
    }

    function _updateDistribution(address _erc20orNative) internal {
        nextDistributions[_erc20orNative] = block.timestamp + minDistributionIntervalSeconds;
    }
}
