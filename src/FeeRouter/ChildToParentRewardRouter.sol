// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";

interface IArbSys {
    function withdrawEth(
        address destination
    ) external payable returns (uint256);
}

/// @notice Receives native funds on an Arbitrum chain and sends them to a target contract on its parent chain.
/// Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
/// (creating many small values messages that each need to be executed in the outbox).
/// A send is automatically attempted any time funds are receieved.
contract ChildToParentRewardRouter is DistributionInterval {
    // contract on this chain's parent chain funds get routed to
    address immutable parentChainTarget;

    event FundsRouted(uint256 amount);

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        parentChainTarget = _parentChainTarget;
    }

    receive() external payable {
        sendFunds();
    }

    /// @notice send all funds in this contract to target contract on parent chain via L2 to L1 message
    function sendFunds() public {
        uint256 value = address(this).balance;
        // if distributing too soon, skip withdrawal (but don't revert)
        if (canDistribute() && value > 0) {
            _updateDistribution();
            IArbSys(address(100)).withdrawEth{value: value}(parentChainTarget);
            emit FundsRouted(value);
        }
    }
}
