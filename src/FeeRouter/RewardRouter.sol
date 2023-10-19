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

contract RewardRouter {
    IInbox immutable inbox;
    address immutable destination;

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
        _routeFounds(maxSubmissionCost, gasLimit, maxFeePerGas, msg.sender);
    }

    function routeFundsCustomRefund(
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        address excessFeeRefundAddress
    ) external payable {
        _routeFounds(
            maxSubmissionCost,
            gasLimit,
            maxFeePerGas,
            excessFeeRefundAddress
        );
    }

    function _routeFounds(
        uint256 maxSubmissionCost,
        uint256 gasLimit,
        uint256 maxFeePerGas,
        address excessFeeRefundAddress
    ) internal {
        require(
            maxFeePerGas * gasLimit + maxSubmissionCost <= msg.value,
            "INSUFFICIENT_VALUE"
        );
        inbox.createRetryableTicket{value: address(this).balance}({
            to: destination,
            l2CallValue: address(this).balance - msg.value,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: excessFeeRefundAddress,
            callValueRefundAddress: destination,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            data: bytes("0x")
        });
    }
}
