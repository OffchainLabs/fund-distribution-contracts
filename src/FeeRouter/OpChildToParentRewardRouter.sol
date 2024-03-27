// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./BaseChildToParentRewardRouter.sol";

interface IOpStandardBridge {
    function bridgeETHTo(address _to, uint32 _minGasLimit, bytes calldata _extraData) external payable;
    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

/// @notice Child to Parent Reward Router deployed to OP Stack chains
contract OpChildToParentRewardRouter is BaseChildToParentRewardRouter {
    IOpStandardBridge public immutable opStandardBridge;

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress,
        address _opStandardBridge
    )
        BaseChildToParentRewardRouter(
            _parentChainTarget,
            _minDistributionIntervalSeconds,
            _parentChainTokenAddress,
            _childChainTokenAddress
        )
    {
        opStandardBridge = IOpStandardBridge(_opStandardBridge);
    }

    function _sendNative(uint256 amount) internal override {
        opStandardBridge.bridgeETHTo{value: amount}(parentChainTarget, 0, "");
    }

    function _sendToken(uint256 amount) internal override {
        // approve for transfer, adding 1 so storage slot doesn't get set to 0, saving gas.
        // (not actually necessary for non-native tokens)
        IERC20(childChainTokenAddress).approve(address(opStandardBridge), amount + 1);

        opStandardBridge.bridgeERC20To(
            childChainTokenAddress, parentChainTokenAddress, parentChainTarget, amount, 0, ""
        );
    }
}
