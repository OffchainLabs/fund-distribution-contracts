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

error NoFundsToDistribute();

error WrongMethod();

/// @notice Accepts funds on a parent chain and routes them to a target contract on a target Arbitrum chain.
/// @dev supports native currency and any number of arbitrary ERC20s. 
contract ParentToChildRewardRouter is DistributionInterval {
    // inbox of target Arbitrum child chain
    IInbox public immutable inbox;
    // Receiving address of funds on target Arbitrum chain
    address public immutable destination;
    // minimum child chain gas price for retryable ticket execution, to prevent spam
    uint256 public immutable minGasPrice;
    // minimum child chain gas limit for retryable ticket execution, to prevent spam
    uint256 public immutable minGasLimit;
    // address of token gateway router on this chain.
    IParentChainGatewayRouter public immutable parentChainGatewayRouter;

    event FundsRouted(address indexed token, uint256 amount);

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

        uint256 amount = address(this).balance - msg.value;
        if (amount == 0) {
            revert NoFundsToDistribute();
        }

        // This method uses unsafeCreateRetryableTicket. Compared to createRetryableTicket, unsafeCreateRetryableTicket leaves out 3 things:
        // 1. check msg.value supplied equals gas required for retryable execution
        // 2. Conditionally alias excessFeeRefundAddress
        // 3. Conditionally alias callValueRefundAddress
        // The rationale for including, modifying, or excluding these things is as follows

        // #1 we include in slightly modified form; we ensure the msg.value covers the cost of execution, tho not including the L2 callvalue.
        // (the L2Callue will be the funds alreday escrowed in this contract) 
        if (maxFeePerGas * gasLimit + maxSubmissionCost != msg.value) {
            revert IncorrectValue(maxFeePerGas * gasLimit + maxSubmissionCost, msg.value);
        }

     
        // #2 we include identically to how it appears in the createRetryableTicket path, and for the same rationale
        // (gives smart contract wallets the opportunity to access funds on the child chain)
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
            // #3 we leave out; i.e., we don't alias the callValueRefundAddress, we simply set it to the destination.
            // This meansf the retryable ticket expires or is cancelled, the L2CallValue is sent to the destination, which
            // is the intended result anyway. 
            callValueRefundAddress: destination, 
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            data: ""
        });
        emit FundsRouted(NATIVE_CURRENCY, amount);
    }

    /// @notice send full token balance in this contract to destination. Uses sender's address for fee refund
    /// @param parentChainTokenAddr address of token on this chain to route
    /// @param maxSubmissionCost submission cost for retryable ticket
    /// @param gasLimit gas limit for l2 execution of retryable ticket
    /// @param maxFeePerGas max gas l2 gas price for retryable ticket
    function routeToken(address parentChainTokenAddr, uint256 maxSubmissionCost, uint256 gasLimit, uint256 maxFeePerGas)
        public
        payable
    {
        // use routeNativeFunds, not this method,  for native currency, 
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
            revert NoFundsToDistribute();
        }
        _updateDistribution(parentChainTokenAddr);
        // get gateway from gateway router
        address gateway = parentChainGatewayRouter.getGateway(address(parentChainTokenAddr));
        // approve amount on gateway
        IERC20(parentChainTokenAddr).approve(gateway, amount);

        // encode max submission cost (and empty callhook data) for gateway router
        bytes memory _data = abi.encode(maxSubmissionCost, bytes(""));

        // As the caller of outboundTransferCustomRefund, this contract's alias is set as the callValueRfundAddress,
        // giving it affordance to cancel and receive callvalue refund. Since this contract can't call cancel, cancellation
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

        emit FundsRouted(parentChainTokenAddr, amount);
    }
}
