// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

contract OpStandardBridgeMock {
    address public constant MESSENGER = 0x4200000000000000000000000000000000000007;

    event BridgeEthTo(address to, uint256 amount, uint32 minGasLimit, bytes extraData);
    event BridgeERC20To(
        address localToken, address remoteToken, address to, uint256 amount, uint32 minGasLimit, bytes extraData
    );

    function bridgeETHTo(address _to, uint32 _minGasLimit, bytes calldata _extraData) external payable {
        emit BridgeEthTo(_to, msg.value, _minGasLimit, _extraData);
    }

    function bridgeERC20To(
        address _localToken,
        address _remoteToken,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external {
        emit BridgeERC20To(_localToken, _remoteToken, _to, _amount, _minGasLimit, _extraData);
    }
}
