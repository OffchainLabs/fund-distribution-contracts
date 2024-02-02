// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "../DistributionInterval.sol";
import "nitro-contracts/src/libraries/AddressAliasHelper.sol";
import "nitro-contracts/src/bridge/IInbox.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

error IncorrectValue(uint256 exactValueRequired, uint256 valueSupplied);

error DistributionTooSoon(
    uint256 currentTimestamp,
    uint256 distributionTimestamp
);

error GasPriceTooLow(uint256 gasPrice);

error GasLimitTooLow(uint256 gasLimit);

error NoFundsToDistrubute();

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

    function getGateway(
        address _parentChainTokenAddress
    ) external view returns (address gateway);
}

/// @notice Accepts funds on a parent chain and routes them to a target contract on a target Arbitrum chain.
contract ParentToChildErc20RewardRouter is DistributionInterval {
    IParentChainGatewayRouter public immutable parentChainGatewayRouter;
    address public immutable parentChainTokenAddress;
    // Receiving address of funds on target Arbitrum chain
    address public immutable destination;

    uint256 public immutable minGasPrice;

    uint public immutable minGasLimit;

    event FundsRouted(uint256 amount);

    constructor(
        address _parentChainGatewayRouter,
        address _parentChainTokenAddress,
        address _destination,
        uint256 _minDistributionIntervalSeconds,
        uint256 _minGasPrice,
        uint256 _minGasLimit
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        parentChainGatewayRouter = IParentChainGatewayRouter(
            _parentChainGatewayRouter
        );
        parentChainTokenAddress = _parentChainTokenAddress;
        destination = _destination;
        minGasPrice = _minGasPrice;
        minGasLimit = _minGasLimit;
    }

    /// @notice send full token balance in this contract to destination. Users sender's address for fee refund
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

        uint256 amount = IERC20(parentChainTokenAddress).balanceOf(
            address(this)
        );

        bytes memory _data = bytes("");   // TODO  encode maxSubmissionCost
      
        if (amount == 0) {
            revert NoFundsToDistrubute();
        }
        _updateDistribution();
        parentChainGatewayRouter.outboundTransferCustomRefund{
            value: msg.value
        }({
            _token: parentChainTokenAddress,
            _refundTo: msg.sender,
            _to: destination,
            _amount: amount,
            _maxGas: gasLimit,
            _gasPriceBid: maxFeePerGas,
            _data: _data
        });

        emit FundsRouted(amount);
    }

    function approveOnGateway() external {
        address gateway = parentChainGatewayRouter.getGateway(
            address(parentChainTokenAddress)
        );
        IERC20(parentChainTokenAddress).approve(gateway, 2 ** 256 - 1);
    }

}