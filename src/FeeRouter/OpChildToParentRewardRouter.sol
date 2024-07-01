// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./DistributionInterval.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./ChildToParentRewardRouter.sol";

interface IOpStandardBridge {
    function MESSENGER() external view returns (address);
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
contract OpChildToParentRewardRouter is ChildToParentRewardRouter {
    IOpStandardBridge public constant opStandardBridge = IOpStandardBridge(0x4200000000000000000000000000000000000010);

    error NotOpStack();

    constructor(
        address _parentChainTarget,
        uint256 _minDistributionIntervalSeconds,
        address _parentChainTokenAddress,
        address _childChainTokenAddress
    )
        ChildToParentRewardRouter(
            _parentChainTarget,
            _minDistributionIntervalSeconds,
            _parentChainTokenAddress,
            _childChainTokenAddress
        )
    {
        // ensure this is an OP Stack chain
        (bool success, bytes memory data) = address(opStandardBridge).staticcall(abi.encodeWithSignature("MESSENGER()"));
        if (!success || data.length != 32 || abi.decode(data, (address)) != 0x4200000000000000000000000000000000000007)
        {
            revert NotOpStack();
        }
    }

    function _sendNative(uint256 amount) internal override {
        opStandardBridge.bridgeETHTo{value: amount}(parentChainTarget, 0, "");
    }

    function _sendToken(uint256 amount) internal override {
        // approve for transfer
        // (not actually necessary for non-native tokens)
        IERC20(childChainTokenAddress).approve(address(opStandardBridge), amount);

        opStandardBridge.bridgeERC20To(
            childChainTokenAddress, parentChainTokenAddress, parentChainTarget, amount, 0, ""
        );
    }
}
