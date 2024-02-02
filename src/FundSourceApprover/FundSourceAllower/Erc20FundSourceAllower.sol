// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./FundSourceAllowerBase.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Funds allower for an Erc20 token
contract Erc20FundSourceAllower is FundSourceAllowerBase {
    using SafeERC20 for IERC20;

    // Erc20 token to receieve / transfer to destination
    IERC20 public immutable token;

    constructor(
        uint256 _sourceChaindId,
        address _destination,
        address _admin,
        address _token
    ) FundSourceAllowerBase(_sourceChaindId, _destination, _admin) {
        token = IERC20(_token);
    }

    /// @notice send full ERC20 balance of funds in contract to destination address
    function _transferFundsToDestination() internal override {
        uint256 value = token.balanceOf(address(this));
        token.safeTransfer(destination, value);
        emit FundsTransfered(value);
    }
}
