// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "./FundSourceAllowerBase.sol";

/// @notice Funds allower for a native currency.
contract NativeFundSourceAllower is FundSourceAllowerBase {
    constructor(
        uint256 _sourceChaindId,
        address _destination,
        address _admin
    ) FundSourceAllowerBase(_sourceChaindId, _destination, _admin) {}

    receive() external payable virtual {
        // Upon receiving funds, if approved, then immediately transfer funds.
        // Otherwise, terminate but don't revert (while not approved, funds can still be received, just not transfered out).
        if (approved) {
            _transferFundsToDestination();
        }
    }

    /// @notice send full native currency balance of funds in contract to destination address
    function _transferFundsToDestination() internal override {
        uint256 value = address(this).balance;
        (bool success, ) = destination.call{value: value}("");
        if (!success) {
            revert TransferFailed();
        }
        emit FundsTransfered(value);
    }
}
