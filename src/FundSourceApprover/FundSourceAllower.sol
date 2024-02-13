// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract FundSourceAllower {
    using SafeERC20 for IERC20;

    // chain id of chain in which funds initiate; used only for bookkeeping
    uint256 public immutable sourceChaindId;
    // address which eth is forwarded to
    address public immutable ethDestination;
    // address which tokens are forwarded to
    address public immutable tokenDestination;
    // address with affordance to approve funds
    address public immutable admin;
    // signifies whether admin has approved transfering of funds to destination
    bool public approved;

    error TransferFailed();
    error NotApproved();
    error NotFromAdmin(address sender);

    event EthTransfered(uint256 amount);
    event TokensTransfered( address indexed token, uint256 amount);
    event ApprovedStateSet(bool approved);

    constructor(uint256 _sourceChaindId, address _ethDestination, address _tokenDestination, address _admin) {
        sourceChaindId = _sourceChaindId;
        ethDestination = _ethDestination;
        tokenDestination = _tokenDestination;
        admin = _admin;
    }

    receive() external payable {
        // Upon receiving funds, if approved, then immediately transfer eth.
        // Otherwise, terminate but don't revert (while not approved, funds can still be received, just not transfered out).
        if (approved) {
            _transferEthToDestination();
        }
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotFromAdmin(msg.sender);
        }
        _;
    }
    /// @notice Send full balance of native funds in contract to destination; only if approved.
    /// Permissionlessly callable.
    function transferEthToDestination() public {
        if (!approved) {
            revert NotApproved();
        }
        _transferEthToDestination();
    }

        /// @notice Send full balance of tokens in contract to destination; only if approved.
        /// @param  _tokenAddr address of token to transfer
    function transferTokenToDestination(address _tokenAddr) public {
        if (!approved) {
            revert NotApproved();
        }
        IERC20 token = IERC20(_tokenAddr);
        uint256 value = token.balanceOf(address(this));
        IERC20(_tokenAddr).safeTransfer(tokenDestination, value);
        // eth transfered vs. token transferd
        emit TokensTransfered(_tokenAddr, value);
    }

    function _transferEthToDestination() internal {
        uint256 value = address(this).balance;
        (bool success,) = ethDestination.call{value: value}("");
        if (!success) {
            revert TransferFailed();
        }
        emit EthTransfered(value);
    }
    /// @notice sets approved to true
    /// Callable only by admin.
    function setApproved() external onlyAdmin {
        approved = true;
        emit ApprovedStateSet(approved);
    }

    /// @notice sets approved to false
    /// Callable only by admin.
    function setNotApproved() external onlyAdmin {
        approved = false;
        emit ApprovedStateSet(approved);
    }
}
