// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ChildToParentRewardRouter.sol";

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

/// @notice Child to Parent Reward Router deployed to Arbitrum chains
contract ArbChildToParentRewardRouter is ChildToParentRewardRouter {
    // address of gateway router on this chain
    IChildChainGatewayRouter public immutable childChainGatewayRouter;

    error TokenDisabled(address tokenAddr);

    error TokenNotRegisteredToGateway(address tokenAddr);

    error NotArbitrum();

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress,
        address _childChainGatewayRouter
    )
        ChildToParentRewardRouter(
            _parentChainTarget,
            _minDistributionIntervalSeconds,
            _parentChainTokenAddress,
            _childChainTokenAddress
        )
    {
        childChainGatewayRouter = IChildChainGatewayRouter(_childChainGatewayRouter);

        // ensure this is an Arbitrum chain
        (bool success, bytes memory data) = address(100).staticcall(abi.encodeWithSignature("arbOSVersion()"));
        if (!success || data.length != 32 || abi.decode(data, (uint256)) == 0) {
            revert NotArbitrum();
        }

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

    function _sendNative(uint256 amount) internal override {
        IArbSys(address(100)).withdrawEth{value: amount}(parentChainTarget);
    }

    function _sendToken(uint256 amount) internal override {
        // get gateway from gateway router
        address gateway = childChainGatewayRouter.getGateway(parentChainTokenAddress);
        // approve for transfer, adding 1 so storage slot doesn't get set to 0, saving gas.
        IERC20(childChainTokenAddress).approve(gateway, amount + 1);
        childChainGatewayRouter.outboundTransfer(parentChainTokenAddress, parentChainTarget, amount, "");
    }
}
