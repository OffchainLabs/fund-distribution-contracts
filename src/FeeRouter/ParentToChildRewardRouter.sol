// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "./DistributionInterval.sol";
import "nitro-contracts/src/libraries/AddressAliasHelper.sol";
import "nitro-contracts/src/bridge/IInbox.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

error IncorrectValue(uint256 exactValueRequired, uint256 valueSupplied);

error DistributionTooSoon(
    uint256 currentTimestamp,
    uint256 distributionTimestamp
);

error GasPriceTooLow(uint256 gasPrice);

error GasLimitTooLow(uint256 gasLimit);

error NoFundsToDistrubute();

/// @notice Accepts funds on a parent chain and routes them to a target contract on a target Arbitrum chain.
contract ParentToChildRewardRouter is DistributionInterval {
    // inbox of target Arbitrum child chain
    IInbox public immutable inbox;
    // Receiving address of funds on target Arbitrum chain
    address public immutable destination;

    uint256 public immutable minGasPrice;

    uint public immutable minGasLimit;

    event FundsRouted(uint256 amount);

    constructor(
        address _inbox,
        address _destination,
        uint256 _minDistributionIntervalSeconds,
        uint256 _minGasPrice,
        uint256 _minGasLimit
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        inbox = IInbox(_inbox);
        destination = _destination;
        minGasPrice = _minGasPrice;
        minGasLimit = _minGasLimit;
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
    ) public payable {
        if (!canDistribute()) {
            revert DistributionTooSoon(block.timestamp, nextDistribution);
        }

        if (gasLimit < minGasLimit) {
            revert GasLimitTooLow(gasLimit);
        }

        if (maxFeePerGas < minGasPrice) {
            revert GasPriceTooLow(maxFeePerGas);
        }

        // while a similar check is performed in the Inbox, this is necessary to ensure only value sent in the transaction is used as gas
        // (i.e., that the message doesn't consume escrowed funds as gas)
        if (maxFeePerGas * gasLimit + maxSubmissionCost != msg.value) {
            revert IncorrectValue(
                maxFeePerGas * gasLimit + maxSubmissionCost,
                msg.value
            );
        }

        /// In the Inbox, callValueRefundAddress is converted to its alias if ParentChain(callValueRefundAddress) is a contract;
        /// this is intended to prevent footguns. In this case, however, callValueRefundAddress should ultimately be the
        /// destination address regardless. This is because if the retryable ticket expires or is cancelled,
        /// the l2 callvalue will be refunded to callValueRefundAddress / destination, which is the intent of this method anyway.
        /// Thus, we preemptively perform the reverse operation here.
        /// Note that even a malicious ParentChain(desintationAddress) contract gets no dangerous affordances.
        address callValueRefundAddress = Address.isContract(destination)
            ? AddressAliasHelper.undoL1ToL2Alias(destination)
            : destination;

        uint256 amount = address(this).balance - msg.value;
        if (amount == 0) {
            revert NoFundsToDistrubute();
        }
        _updateDistribution();
        inbox.createRetryableTicket{value: address(this).balance}({
            to: destination,
            l2CallValue: amount,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: msg.sender,
            callValueRefundAddress: callValueRefundAddress,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            data: ""
        });
        emit FundsRouted(amount);
    }
}
