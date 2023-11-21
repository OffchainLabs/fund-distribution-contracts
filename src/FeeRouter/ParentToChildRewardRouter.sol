// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "./DistributionInterval.sol";

interface IInbox {
    function createRetryableTicket(
        address to,
        uint256 l2CallValue,
        uint256 maxSubmissionCost,
        address excessFeeRefundAddress,
        address callValueRefundAddress,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        bytes calldata data
    ) external payable returns (uint256);
}
error InsufficientValue(uint256 valueRequired, uint256 valueSupplied);

/// @notice Accepts funds on a parent chain and routes them to a target contract on a target Arbitrum chain.
contract ParentToChildRewardRouter is DistributionInterval {
    // inbox of target Arbitrum child chain
    IInbox immutable inbox;
    // Receiving address of funds on target Arbitrum chain
    address immutable destination;

    event FoundsRouted(address indexed refundAddress, uint256 amount);

    constructor(
        address _inbox,
        address _destination,
        uint256 _minDistributionIntervalSeconds
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        inbox = IInbox(_inbox);
        destination = _destination;
    }

    receive() external payable {}

    /// @notice send all native funds in this contract to destination. Users sender's address for fee refund
    /// @param maxSubmissionCost submission cost for retryable ticket
    /// @param gasLimit gas limit for l2 execution of retryable ticket
    /// @param maxFeePerGas max gas l2 gas price for retryable ticket
    function routeFunds(
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas
    ) external payable {
        routeFundsCustomRefund(
            maxSubmissionCost,
            gasLimit,
            maxFeePerGas,
            msg.sender
        );
    }

    /// @param maxSubmissionCost submission cost for retryable ticket
    /// @param gasLimit gas limit for l2 execution of retryable ticket
    /// @param maxFeePerGas max gas l2 gas price for retryable ticket
    /// @param excessFeeRefundAddress Address at which excess fee get sent on the child chain
    function routeFundsCustomRefund(
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        address excessFeeRefundAddress
    ) public payable ifCanDistribute {
        // while a similar check is performed in the Inbox, this is necessary to ensure only value sent in the transaction is used as gas
        // (i.e., that the message doesn't consume escrowed funds as gas)
        if (maxFeePerGas * gasLimit + maxSubmissionCost != msg.value) {
            revert InsufficientValue(
                maxFeePerGas * gasLimit + maxSubmissionCost,
                msg.value
            );
        }
        uint256 amount = address(this).balance - msg.value;
        _updateDistribution();
        inbox.createRetryableTicket{value: address(this).balance}({
            to: destination,
            l2CallValue: amount,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: excessFeeRefundAddress,
            callValueRefundAddress: destination,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            data: ""
        });
        emit FoundsRouted(excessFeeRefundAddress, amount);
    }
}
