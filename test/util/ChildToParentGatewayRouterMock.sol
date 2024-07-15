// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

contract ChildToParentGatewayRouterMock {
    event OutboundTransfer(address token, address to, uint256 amount, bytes data);

    mapping(address => address) public getGateway;
    mapping(address => address) public calculateL2TokenAddress;

    function setGateway(address token, address gateway) public {
        getGateway[token] = gateway;
    }

    function setL2TokenAddress(address token, address l2Token) public {
        calculateL2TokenAddress[token] = l2Token;
    }

    function outboundTransfer(address token, address to, uint256 amount, bytes memory data)
        public
        returns (bytes memory)
    {
        emit OutboundTransfer(token, to, amount, data);
    }
}
