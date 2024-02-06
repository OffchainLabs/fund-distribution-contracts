// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../DistributionInterval.sol";

interface IChildChainGatewayRouter {
    function outboundTransfer(address _parentChainTokenAddress, address _to, uint256 _amount, bytes calldata _data)
        external
        payable
        returns (bytes memory);

    function getGateway(address _parentChainTokenAddress) external view returns (address gateway);

    // outdated name; read this as "calculateChildChainTokenAddress"
    function calculateL2TokenAddress(address _parentChainTokenAddress) external returns (address);
}
/// @notice Receives tokens on an Arbitrum chain and sends them to a target contract on its parent chain.
/// Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
/// (creating many small values messages that each need to be executed in the outbox).

contract ChildToParentErc20RewardRouter is DistributionInterval {
    // contract on this chain's parent chain funds get routed to
    address public immutable parentChainTarget;
    // address of token on parent chain
    IERC20 public immutable parentChainToken;
    // address of token on this child
    address public immutable childChainTokenAddress;

    IChildChainGatewayRouter public immutable childChainGatewayRouter;

    error TokenNotRegisteredToGateway();

    event FundsRouted(uint256 amount);

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress,
        address _childChainGatewayRouter
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        parentChainTarget = _parentChainTarget;
        parentChainToken = IERC20(_parentChainTokenAddress);
        childChainGatewayRouter = IChildChainGatewayRouter(_childChainGatewayRouter);

        // note that _childChainTokenAddress can be retrieved from _parentChainTokenAddress, but we
        // requrie it as a paramter as an additional sanity check
        address calculatedChildChainTokenAddress =
            childChainGatewayRouter.calculateL2TokenAddress(_parentChainTokenAddress);
        if (_childChainTokenAddress != calculatedChildChainTokenAddress) {
            revert TokenNotRegisteredToGateway();
        }
        childChainTokenAddress = _childChainTokenAddress;

        address gateway = childChainGatewayRouter.getGateway(_parentChainTokenAddress);

        if (gateway == address(0)) {
            revert TokenNotRegisteredToGateway();
        }

        // approve on gateway
        approveGateway();
    }

    ///@notice Approve token's gateway; can be recalled to approve the new gateway if it ever changes.
    function approveGateway() public {
        // get gateway from gateway router
        address gateway = childChainGatewayRouter.getGateway(address(parentChainToken));
        IERC20(childChainTokenAddress).approve(gateway, 2 ** 256 - 1);
    }
    /// @notice withdraw full token balance to parentChainTarget; only callable once per distribution internal

    function routeFunds() public {
        uint256 value = parentChainToken.balanceOf(address(this));
        if (canDistribute() && value > 0) {
            _updateDistribution();
            childChainGatewayRouter.outboundTransfer(address(parentChainToken), parentChainTarget, value, "");
            emit FundsRouted(value);
        }
    }
}
