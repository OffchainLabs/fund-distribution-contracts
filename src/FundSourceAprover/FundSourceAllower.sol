// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

contract FundSourceAllower {
    address public immutable fundSender;
    uint256 public immutable sourceChaindId;
    address public immutable destination;
    address public immutable admin;

    bool public approved;

    error NotFromFundSender(address sender);
    error TransferFailed();
    error NotApproved();
    error NotFromAdmin(address sender);

    event FundsTransfered(uint256 amount);
    event ApprovedToggled(bool approved);

    constructor(
        address _fundSender,
        uint256 _sourceChaindId,
        address _destination,
        address _admin
    ) {
        fundSender = _fundSender;
        sourceChaindId = _sourceChaindId;
        destination = _destination;
        admin = _admin;
    }

    receive() external payable {
        if (msg.sender != fundSender) {
            revert NotFromFundSender(msg.sender);
        }
        if (approved) {
            _transferFundsToDestination();
        }
    }

    function _transferFundsToDestination() internal {
        uint256 value = address(this).balance;
        (bool success, ) = destination.call{value: value}("");
        if (!success) {
            revert TransferFailed();
        }
        emit FundsTransfered(value);
    }

    function transferFundsToDestination() external {
        if (!approved) {
            revert NotApproved();
        }
        _transferFundsToDestination();
    }

    function toggleApproved() external returns (bool) {
        if (msg.sender != admin) {
            revert NotFromAdmin(msg.sender);
        }
        approved = !approved;
        emit ApprovedToggled(approved);
        return approved;
    }
}
