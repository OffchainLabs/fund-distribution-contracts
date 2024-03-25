// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./OpChildToParentRewardRouter.sol";

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

/// @notice Receives native funds and a single ERC20 funds (set on deployment) on an Arbitrum chain and sends them to a target contract on its parent chain.
///         Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
///         (creating many small values messages that each need to be executed in the outbox).
///         A send is automatically attempted when native funds are receieved in the receive function.
/// @dev    For native only (i.e., no token), deploy with parentChainTokenAddress, childChainTokenAddress, and childChainGatewayRouter == address(1).
contract ChildToParentRewardRouter is BaseChildToParentRewardRouter {
    // address of gateway router on this chain
    IChildChainGatewayRouter public immutable childChainGatewayRouter;

    error TokenDisabled(address tokenAddr);

    error TokenNotRegisteredToGateway(address tokenAddr);

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress,
        address _childChainGatewayRouter
    ) BaseChildToParentRewardRouter(_parentChainTarget, _minDistributionIntervalSeconds, _parentChainTokenAddress, _childChainTokenAddress) {
        childChainGatewayRouter = IChildChainGatewayRouter(_childChainGatewayRouter);

        // If a token is enabled, include token sanity checks
        if (_parentChainTokenAddress != address(1)) {
            // note that _childChainTokenAddress can be retrieved from _parentChainTokenAddress, but we
            // require it as a parameter as an additional sanity check
            address calculatedChildChainTokenAddress =
                childChainGatewayRouter.calculateL2TokenAddress(_parentChainTokenAddress);
            if (_childChainTokenAddress != calculatedChildChainTokenAddress) {
                revert TokenNotRegisteredToGateway(_parentChainTokenAddress);
            }
            // check if token is disabled
            address gateway = childChainGatewayRouter.getGateway(_parentChainTokenAddress);

            if (gateway == address(0)) {
                revert TokenDisabled(_parentChainTokenAddress);
            }
        }
    }

    function _withdrawNative(uint256 amount) internal override {
        IArbSys(address(100)).withdrawEth{value: amount}(parentChainTarget);
    }

    function _withdrawToken(uint256 amount) internal override {
        // get gateway from gateway router
        address gateway = childChainGatewayRouter.getGateway(parentChainTokenAddress);
        // approve for transfer, adding 1 so storage slot doesn't get set to 0, saving gas.
        IERC20(childChainTokenAddress).approve(gateway, amount + 1);
        childChainGatewayRouter.outboundTransfer(parentChainTokenAddress, parentChainTarget, amount, "");
    }
}
