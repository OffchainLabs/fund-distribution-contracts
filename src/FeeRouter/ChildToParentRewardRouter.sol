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

// TODO update comments
/// @notice Receives native and ERC20 funds on an Arbitrum chain and sends them to a target contract on its parent chain.
///         Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
///         (creating many small values messages that each need to be executed in the outbox).
///         A send is automatically attempted when native funds are receieved in the receive function.
contract ChildToParentRewardRouter is DistributionInterval {
       // contract on this chain's parent chain funds get routed to
    address public immutable parentChainTarget;
    // address of token on parent chain
    address public immutable parentChainTokenAddress;
    // address of token on this child
    address public immutable childChainTokenAddress;

    IChildChainGatewayRouter public immutable childChainGatewayRouter;

    event FundsRouted(address indexed token, uint256 amount);

    error NoValue(address tokenAddr);

    error TokenDisabled(address tokenAddr);

    error TokenNotRegisteredToGateway(address tokenAddr);


  
    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress,
        address _childChainGatewayRouter
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        parentChainTarget = _parentChainTarget;
        parentChainTokenAddress = _parentChainTokenAddress;
        childChainGatewayRouter = IChildChainGatewayRouter(_childChainGatewayRouter);

        // note that _childChainTokenAddress can be retrieved from _parentChainTokenAddress, but we
        // require it as a parameter as an additional sanity check
        address calculatedChildChainTokenAddress =
            childChainGatewayRouter.calculateL2TokenAddress(parentChainTokenAddress);
        if (_childChainTokenAddress != calculatedChildChainTokenAddress) {
            revert TokenNotRegisteredToGateway(parentChainTokenAddress);
        }
        childChainTokenAddress = _childChainTokenAddress;

        address gateway = childChainGatewayRouter.getGateway(parentChainTokenAddress);

        if (gateway == address(0)) {
            revert TokenDisabled(parentChainTokenAddress);
        }
    }

    /// @dev This receive function should NEVER revert
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
            emit FundsRouted(NATIVE_CURRENCY,value);
        }
    }

    /// @notice withdraw full token balance to parentChainTarget; only callable once per distribution interval

    function routeFunds() public {
        uint256 value = IERC20(childChainTokenAddress).balanceOf(address(this));
        // get gateway from gateway router
        address gateway = childChainGatewayRouter.getGateway(parentChainTokenAddress);
        // approve for transfer
        if (canDistribute(parentChainTokenAddress) && value > 0) {
            _updateDistribution(parentChainTokenAddress);
            IERC20(childChainTokenAddress).approve(gateway, value);
            childChainGatewayRouter.outboundTransfer(parentChainTokenAddress, parentChainTarget, value, "");
            emit FundsRouted(parentChainTokenAddress,value);
        }
    }
}
