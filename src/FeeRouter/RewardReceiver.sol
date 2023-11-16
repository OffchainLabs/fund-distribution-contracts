// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IArbSys {
    function withdrawEth(
        address destination
    ) external payable returns (uint256);
}

/// @notice Receives native funds on an Arbitrum chain and sends them to a target contract on its parent chain.
/// Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
/// (creating many small values messages that each need to be executed in the outbox).
/// A send is automatically attempted any time funds are receieved.
contract RewardReceiver {
    // contract on this chain's parent chain funds get routed to
    address immutable parentChainTarget;
    // minumum time between L2 to L1 messages from this contract
    uint256 immutable minDistributionIntervalSeconds;
    // time at which next L2 to L1 message can get sent
    uint256 public nextDistribution;

    event FundsSent(uint256 amount);

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds
    ) {
        parentChainTarget = _parentChainTarget;
        minDistributionIntervalSeconds = _minDistributionIntervalSeconds;
    }

    receive() external payable {
        sendFunds();
    }

    /// @notice send all funds in this contract to target contract on parent chain via L2 to L1 message
    function sendFunds() public {
        // if distributing too soon, skip withdrawal (but don't revert)
        if (block.timestamp >= nextDistribution) {
            nextDistribution = block.timestamp + minDistributionIntervalSeconds;
            uint256 value = address(this).balance;
            IArbSys(address(100)).withdrawEth{value: value}(parentChainTarget);
            emit FundsSent(value);
        }
    }
}
