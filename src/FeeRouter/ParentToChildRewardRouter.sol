// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "nitro-contracts/src/libraries/AddressAliasHelper.sol";
import "nitro-contracts/src/bridge/IInbox.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IParentChainGatewayRouter {
    function outboundTransferCustomRefund(
        address _token,
        address _refundTo,
        address _to,
        uint256 _amount,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        bytes calldata _data
    ) external payable returns (bytes memory);

    function getGateway(address _parentChainTokenAddress) external view returns (address gateway);
    function inbox() external view returns (address);
}

error IncorrectValue(uint256 exactValueRequired, uint256 valueSupplied);

error GasPriceTooLow(uint256 gasPrice);

error GasLimitTooLow(uint256 gasLimit);

error NoFundsToDistrubute();

error WrongMethod();

/// @notice Accepts funds on a parent chain and routes them to a target contract on a target Arbitrum chain.
contract ParentToChildRewardRouter is DistributionInterval {
    // inbox of target Arbitrum child chain
    IInbox public immutable inbox;
    // Receiving address of funds on target Arbitrum chain
    address public immutable destination;

    uint256 public immutable minGasPrice;

    uint256 public immutable minGasLimit;

    IParentChainGatewayRouter public immutable parentChainGatewayRouter;

    event FundsRouted(uint256 amount);

    constructor(
        IParentChainGatewayRouter _parentChainGatewayRouter,
        address _destination,
        uint256 _minDistributionIntervalSeconds,
        uint256 _minGasPrice,
        uint256 _minGasLimit
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        parentChainGatewayRouter = _parentChainGatewayRouter;
        inbox = IInbox(parentChainGatewayRouter.inbox());
        destination = _destination;
        minGasPrice = _minGasPrice;
        minGasLimit = _minGasLimit;
    }

    receive() external payable {}

    /// @notice send all native funds in this contract to destination. Uses sender's address for fee refund
    /// @param maxSubmissionCost submission cost for retryable ticket
    /// @param gasLimit gas limit for l2 execution of retryable ticket
    /// @param maxFeePerGas max gas l2 gas price for retryable ticket
    function routeNativeFunds(uint256 maxSubmissionCost, uint256 gasLimit, uint256 maxFeePerGas) public payable {
        if (!canDistribute(NATIVE_CURRENCY)) {
            revert DistributionTooSoon(block.timestamp, nextDistributions[NATIVE_CURRENCY]);
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
            revert IncorrectValue(maxFeePerGas * gasLimit + maxSubmissionCost, msg.value);
        }

        // TODO update
        /// In the Inbox, callValueRefundAddress is converted to its alias if ParentChain(callValueRefundAddress) is a contract;
        /// this is intended to prevent footguns. In this case, however, callValueRefundAddress should ultimately be the
        /// destination address regardless. This is because if the retryable ticket expires or is cancelled,
        /// the l2 callvalue will be refunded to callValueRefundAddress / destination, which is the intent of this method anyway.
        /// Thus, we preemptively perform the reverse operation here.
        /// Note that even a malicious ParentChain(desintationAddress) contract gets no dangerous affordances.

        uint256 amount = address(this).balance - msg.value;
        if (amount == 0) {
            revert NoFundsToDistrubute();
        }

        // TODO: comment
        address excessFeeRefundAddress = msg.sender;
        if (Address.isContract(excessFeeRefundAddress)) {
            excessFeeRefundAddress = AddressAliasHelper.applyL1ToL2Alias(excessFeeRefundAddress);
        }

        _updateDistribution(NATIVE_CURRENCY);
        inbox.unsafeCreateRetryableTicket{value: address(this).balance}({
            to: destination,
            l2CallValue: amount,
            maxSubmissionCost: maxSubmissionCost,
            excessFeeRefundAddress: excessFeeRefundAddress,
            callValueRefundAddress: destination, // TODO comment
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            data: ""
        });
        emit FundsRouted(amount);
    }

    /// @notice send full token balance in this contract to destination. Uses sender's address for fee refund
    /// @param parentChainTokenAddr todor
    /// @param maxSubmissionCost submission cost for retryable ticket
    /// @param gasLimit gas limit for l2 execution of retryable ticket
    /// @param maxFeePerGas max gas l2 gas price for retryable ticket
    function routeToken(address parentChainTokenAddr, uint256 maxSubmissionCost, uint256 gasLimit, uint256 maxFeePerGas)
        public
        payable
    {
        // use routeNativeFunds for native currency, not this method
        if (parentChainTokenAddr == NATIVE_CURRENCY) {
            revert WrongMethod();
        }
        if (!canDistribute(parentChainTokenAddr)) {
            revert DistributionTooSoon(block.timestamp, nextDistributions[parentChainTokenAddr]);
        }

        if (gasLimit < minGasLimit) {
            revert GasLimitTooLow(gasLimit);
        }

        if (maxFeePerGas < minGasPrice) {
            revert GasPriceTooLow(maxFeePerGas);
        }

        uint256 amount = IERC20(parentChainTokenAddr).balanceOf(address(this));
        if (amount == 0) {
            revert NoFundsToDistrubute();
        }
        // get gateway from gateway router
        address gateway = parentChainGatewayRouter.getGateway(address(parentChainTokenAddr));
        // approve amount on gateway
        IERC20(parentChainTokenAddr).approve(gateway, amount);

        // encode max submission cost (and empty callhook data) for gateway router
        bytes memory _data = abi.encode(maxSubmissionCost, bytes(""));

        _updateDistribution(parentChainTokenAddr);
        // As the caller of outboundTransferCustomRefund, this contract's alias is set as the callValueRfundAddress,
        // given it affordance to cancel and receive callvalue refund. Since this contract can't call cancel, cancellation
        // can't be performed. Generally calls to outboundTransferCustomRefund will create retryables with zero callValue
        // (and even if there is callvalue, the refund would only take effect if the retryable expires).
        parentChainGatewayRouter.outboundTransferCustomRefund{value: msg.value}({
            _token: parentChainTokenAddr,
            _refundTo: msg.sender, // send excess fees to the sender's address on the child chain
            _to: destination,
            _amount: amount,
            _maxGas: gasLimit,
            _gasPriceBid: maxFeePerGas,
            _data: _data
        });

        emit FundsRouted(amount);
    }
}
