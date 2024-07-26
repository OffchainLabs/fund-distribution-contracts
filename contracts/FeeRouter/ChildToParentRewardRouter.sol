// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice Receives native funds and a single ERC20 funds (set on deployment) and sends them to a target contract on its parent chain.
///         Funds can only be sent once every minDistributionIntervalSeconds to prevent griefing
///         (creating many small values messages that each need to be executed on the parent chain).
///         A send is automatically attempted when native funds are receieved in the receive function.
/// @dev    For native only (i.e., no token), deploy with parentChainTokenAddress and childChainTokenAddress == address(1).
abstract contract ChildToParentRewardRouter is DistributionInterval {
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
        if (
            _parentChainTarget == address(0) || _parentChainTokenAddress == address(0)
                || _childChainTokenAddress == address(0)
        ) {
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

    /// @notice send all native funds in this contract to target contract on parent chain via L2 to L1 message
    function routeNativeFunds() public {
        uint256 value = address(this).balance;
        // if distributing too soon, or there's no value to distribute, skip withdrawal (but don't revert)
        if (canDistribute(NATIVE_CURRENCY) && value > 0) {
            _updateDistribution(NATIVE_CURRENCY);
            _sendNative(value);
            emit FundsRouted(NATIVE_CURRENCY, value);
        }
    }

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
            _sendToken(value);
            emit FundsRouted(parentChainTokenAddress, value);
        }
    }

    /// @notice Send native funds to parentChainTarget
    /// @dev    This function should NEVER revert
    function _sendNative(uint256 amount) internal virtual;

    /// @notice Send token funds to parentChainTarget
    function _sendToken(uint256 amount) internal virtual;
}
