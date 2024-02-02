// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

/// @notice Accepts funds which can then be forwarded to a destination only while "approved"; admin controls "approved" state.
abstract contract FundSourceAllowerBase {
    // chain id of chain in which funds initiate; used only for bookkeeping
    uint256 public immutable sourceChaindId;
    // address which funds are forwarded to
    address public immutable destination;
    // address with affordance to approve funds
    address public immutable admin;
    // signifies whether admin has approved transfering of funds to destination
    bool public approved;

    error TransferFailed();
    error NotApproved();
    error NotFromAdmin(address sender);

    event FundsTransfered(uint256 amount);
    event ApprovedToggled(bool approved);

    constructor(uint256 _sourceChaindId, address _destination, address _admin) {
        sourceChaindId = _sourceChaindId;
        destination = _destination;
        admin = _admin;
    }

    function _transferFundsToDestination() internal virtual;

    /// @notice Send full balance of funds in contract to destination; only if approved.
    /// Permissionlessly callable.
    function transferFundsToDestination() external {
        if (!approved) {
            revert NotApproved();
        }
        _transferFundsToDestination();
    }

    /// @notice Toggles the approved boolean to allow / disallow funds to be transferred to destination.
    /// Callable only by admin.
    function toggleApproved() external returns (bool) {
        if (msg.sender != admin) {
            revert NotFromAdmin(msg.sender);
        }
        approved = !approved;
        emit ApprovedToggled(approved);
        return approved;
    }
}
