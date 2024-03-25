// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract BaseChildToParentRewardRouter is DistributionInterval {
    // contract on this chain's parent chain funds (native and token) get routed to
    address public immutable parentChainTarget;
    // address of token on parent chain; set to address(1) for only-native support.
    address public immutable parentChainTokenAddress;
    // address of token on this chain
    address public immutable childChainTokenAddress;

    event FundsRouted(address indexed token, uint256 amount);

    error NativeOnly();

    error ZeroAddress();

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress
    ) DistributionInterval(_minDistributionIntervalSeconds) {
        if (_parentChainTarget == address(0)) {
            revert ZeroAddress();
        }
        parentChainTarget = _parentChainTarget;
        parentChainTokenAddress = _parentChainTokenAddress;
        childChainTokenAddress = _childChainTokenAddress;
    }

    /// @dev This receive function should NEVER revert
    receive() external payable {
        // automatically attempt to send native funds upon receiving
        routeNativeFunds();
    }

    function _withdrawNative(uint256 amount) internal virtual;

    /// @notice send all native funds in this contract to target contract on parent chain via L2 to L1 message
    function routeNativeFunds() public {
        uint256 value = address(this).balance;
        // if distributing too soon, or there's no value to distribute, skip withdrawal (but don't revert)
        if (canDistribute(NATIVE_CURRENCY) && value > 0) {
            _updateDistribution(NATIVE_CURRENCY);
            _withdrawNative(value);
            emit FundsRouted(NATIVE_CURRENCY, value);
        }
    }

    function _withdrawToken(uint256 amount) internal virtual;

    /// @notice withdraw full token balance to parentChainTarget; only callable once per distribution interval
    function routeToken() public {
        // revert if contract deployed to be native-only
        if (parentChainTokenAddress == address(1)) {
            revert NativeOnly();
        }
        uint256 value = IERC20(childChainTokenAddress).balanceOf(address(this));
        // get gateway from gateway router
        if (canDistribute(parentChainTokenAddress) && value > 0) {
            _updateDistribution(parentChainTokenAddress);
            _withdrawToken(value);
            emit FundsRouted(parentChainTokenAddress, value);
        }
    }
}

// contract ArbChildToParentRewardRouter is BaseChildToParentRewardRouter {
//     // address of gateway router on this chain
//     IChildChainGatewayRouter public immutable childChainGatewayRouter;

//     error TokenDisabled(address tokenAddr);

//     error TokenNotRegisteredToGateway(address tokenAddr);

//     constructor(
//         address _parentChainTarget,
//         uint256 _minDistributionIntervalSeconds,
//         address _parentChainTokenAddress,
//         address _childChainTokenAddress,
//         address _childChainGatewayRouter
//     ) BaseChildToParentRewardRouter(_parentChainTarget, _minDistributionIntervalSeconds, _parentChainTokenAddress, _childChainTokenAddress) {
//         childChainGatewayRouter = IChildChainGatewayRouter(_childChainGatewayRouter);

//         // If a token is enabled, include token sanity checks
//         if (_parentChainTokenAddress != address(1)) {
//             // note that _childChainTokenAddress can be retrieved from _parentChainTokenAddress, but we
//             // require it as a parameter as an additional sanity check
//             address calculatedChildChainTokenAddress =
//                 childChainGatewayRouter.calculateL2TokenAddress(_parentChainTokenAddress);
//             if (_childChainTokenAddress != calculatedChildChainTokenAddress) {
//                 revert TokenNotRegisteredToGateway(_parentChainTokenAddress);
//             }
//             // check if token is disabled
//             address gateway = childChainGatewayRouter.getGateway(_parentChainTokenAddress);

//             if (gateway == address(0)) {
//                 revert TokenDisabled(_parentChainTokenAddress);
//             }
//         }
//     }

//     function _withdrawNative(uint256 amount) internal override {
//         IArbSys(address(100)).withdrawEth{value: amount}(parentChainTarget);
//     }

//     function _withdrawToken(uint256 amount) internal override {
//         // get gateway from gateway router
//         address gateway = childChainGatewayRouter.getGateway(parentChainTokenAddress);
//         // approve for transfer, adding 1 so storage slot doesn't get set to 0, saving gas.
//         IERC20(childChainTokenAddress).approve(gateway, amount + 1);
//         childChainGatewayRouter.outboundTransfer(parentChainTokenAddress, parentChainTarget, amount, "");
//     }
// }

/// @notice Receives native funds and a single ERC20 funds (set on deployment) on an OP stack chain and sends them to a target contract on its parent chain.
///         Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
///         (creating many small values messages that each need to be executed in the outbox).
///         A send is automatically attempted when native funds are receieved in the receive function.
/// @dev    For native only (i.e., no token), deploy with parentChainTokenAddress, childChainTokenAddress, and childChainGatewayRouter == address(1).
// contract OpChildToParentRewardRouter is DistributionInterval {
//     // contract on this chain's parent chain funds (native and token) get routed to
//     address public immutable parentChainTarget;
//     // address of token on parent chain; set to address(1) for only-native support.
//     address public immutable parentChainTokenAddress;
//     // address of token on this chain
//     address public immutable childChainTokenAddress;
//     // address of gateway router on this chain
//     IChildChainGatewayRouter public immutable childChainGatewayRouter;

//     event FundsRouted(address indexed token, uint256 amount);

//     error NoValue(address tokenAddr);

//     error TokenDisabled(address tokenAddr);

//     error TokenNotRegisteredToGateway(address tokenAddr);

//     error NativeOnly();

//     error ZeroAddress();

//     constructor(
//         address _parentChainTarget,
//         uint256 _minDistributionIntervalSeconds,
//         address _parentChainTokenAddress,
//         address _childChainTokenAddress,
//         address _childChainGatewayRouter
//     ) DistributionInterval(_minDistributionIntervalSeconds) {
//         if (_parentChainTarget == address(0)) {
//             revert ZeroAddress();
//         }
//         parentChainTarget = _parentChainTarget;
//         parentChainTokenAddress = _parentChainTokenAddress;
//         childChainGatewayRouter = IChildChainGatewayRouter(_childChainGatewayRouter);
//         childChainTokenAddress = _childChainTokenAddress;

//         // If a token is enabled, include token sanity checks
//         if (parentChainTokenAddress != address(1)) {
//             // note that _childChainTokenAddress can be retrieved from _parentChainTokenAddress, but we
//             // require it as a parameter as an additional sanity check
//             address calculatedChildChainTokenAddress =
//                 childChainGatewayRouter.calculateL2TokenAddress(parentChainTokenAddress);
//             if (_childChainTokenAddress != calculatedChildChainTokenAddress) {
//                 revert TokenNotRegisteredToGateway(parentChainTokenAddress);
//             }
//             // check if token is disabled
//             address gateway = childChainGatewayRouter.getGateway(parentChainTokenAddress);

//             if (gateway == address(0)) {
//                 revert TokenDisabled(parentChainTokenAddress);
//             }
//         }
//     }

//     /// @dev This receive function should NEVER revert
//     receive() external payable {
//         // automatically attempt to send native funds upon receiving
//         routeNativeFunds();
//     }

//     /// @notice send all native funds in this contract to target contract on parent chain via L2 to L1 message
//     function routeNativeFunds() public {
//         uint256 value = address(this).balance;
//         // if distributing too soon, or there's no value to distribute, skip withdrawal (but don't revert)
//         if (canDistribute(NATIVE_CURRENCY) && value > 0) {
//             _updateDistribution(NATIVE_CURRENCY);
//             IArbSys(address(100)).withdrawEth{value: value}(parentChainTarget);
//             emit FundsRouted(NATIVE_CURRENCY, value);
//         }
//     }

//     /// @notice withdraw full token balance to parentChainTarget; only callable once per distribution interval
//     function routeToken() public {
//         // revert if contract deployed to be native-only
//         if (parentChainTokenAddress == address(1)) {
//             revert NativeOnly();
//         }
//         uint256 value = IERC20(childChainTokenAddress).balanceOf(address(this));
//         // get gateway from gateway router
//         address gateway = childChainGatewayRouter.getGateway(parentChainTokenAddress);
//         if (canDistribute(parentChainTokenAddress) && value > 0) {
//             _updateDistribution(parentChainTokenAddress);
//             // approve for transfer, adding 1 so storage slot doesn't get set to 0, saving gas.
//             IERC20(childChainTokenAddress).approve(gateway, value + 1);
//             childChainGatewayRouter.outboundTransfer(parentChainTokenAddress, parentChainTarget, value, "");
//             emit FundsRouted(parentChainTokenAddress, value);
//         }
//     }
// }
