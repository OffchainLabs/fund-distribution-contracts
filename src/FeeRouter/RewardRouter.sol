// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

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

contract RewardRouter {
    IInbox immutable inbox;
    address immutable destination;

    event FoundsRouted(address indexed refundAddress, uint256 amount);

    constructor(address _inbox, address _destination) {
        inbox = IInbox(_inbox);
        destination = _destination;
    }

    receive() external payable {}

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

    function routeFundsCustomRefund(
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        address excessFeeRefundAddress
    ) public payable {
        if (maxFeePerGas * gasLimit + maxSubmissionCost > msg.value) {
            revert InsufficientValue(
                maxFeePerGas * gasLimit + maxSubmissionCost,
                msg.value
            );
        }
        uint256 amount = address(this).balance - msg.value;
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
