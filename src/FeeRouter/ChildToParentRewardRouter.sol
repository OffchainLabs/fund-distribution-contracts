// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IArbSys {
    function withdrawEth(address destination) external payable returns (uint256);
}

interface IChildChainGatewayRouter {
    function outboundTransfer(address _parentChainTokenAddress, address _to, uint256 _amount, bytes calldata _data)
        external
        payable
        returns (bytes memory);

    function getGateway(address _parentChainTokenAddress) external view returns (address gateway);

    // outdated name; read this as "calculateChildChainTokenAddress"
    function calculateL2TokenAddress(address _parentChainTokenAddress) external returns (address);
}

/// @notice Receives native and ERC20 funds on an Arbitrum chain and sends them to a target contract on its parent chain.
/// Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
/// (creating many small values messages that each need to be executed in the outbox).
/// A send is automatically attempted any time funds are receieved.
contract ChildToParentRewardRouter is DistributionInterval {
    // contract on this chain's parent chain funds get routed to
    address immutable parentChainTarget;
    IChildChainGatewayRouter public immutable childChainGatewayRouter;

    event FundsRouted(uint256 amount);

    error NoValue(address tokenAddr);

    error TokenDisabled(address tokenAddr);


    constructor(
        address _parentChainTarget,
        IChildChainGatewayRouter _childChainGatewayRouter,
        uint256 _minDistributionIntervalSeconds
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        parentChainTarget = _parentChainTarget;
        childChainGatewayRouter = _childChainGatewayRouter;
    }

    receive() external payable {
        // automatically attempt to send native funds upon receiving
        routeNativeFunds();
    }

    /// @notice send all native funds in this contract to target contract on parent chain via L2 to L1 message
    function routeNativeFunds() public {
        uint256 value = address(this).balance;
        // if distributing too soon, or there's no value to distribute, skip withdrawal (but don't revert)
        if (canDistribute(NATIVE_CURRENCY) && value > 0) {
            _updateDistribution(NATIVE_CURRENCY);
            IArbSys(address(100)).withdrawEth{value: value}(parentChainTarget);
            emit FundsRouted(value);
        }
    }

    /// @notice send all of provided token in this contract to destination on parent chain
    /// @param _parentChainTokenAddr parent chain (i.e., chaun underlying this one) address of token to route
    function routeToken(address _parentChainTokenAddr) external {
        address gateway = childChainGatewayRouter.getGateway(_parentChainTokenAddr);

        if (gateway == address(0)) {
            revert TokenDisabled(_parentChainTokenAddr);
        }
        address childChainTokenAddress = childChainGatewayRouter.calculateL2TokenAddress(_parentChainTokenAddr);

        uint256 value = IERC20(childChainTokenAddress).balanceOf(address(this));

        if (!canDistribute(_parentChainTokenAddr)) {
            revert DistributionTooSoon(block.timestamp, nextDistributions[_parentChainTokenAddr]);
        }
        if (value == 0) {
            revert NoValue(_parentChainTokenAddr);
        }
        IERC20(childChainTokenAddress).approve(gateway, value);

        childChainGatewayRouter.outboundTransfer(_parentChainTokenAddr, parentChainTarget, value, "");

        _updateDistribution(_parentChainTokenAddr);
    }
}
