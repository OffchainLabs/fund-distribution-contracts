// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IWETH {
    function balanceOf(address account) external view returns (uint256);
    function withdraw(uint256 amount) external;
}

/// @notice Unwraps all WETH held by this contract and sends the native balance to an immutable recipient
contract WethUnwrapper {
    IWETH public immutable weth;
    address public immutable recipient;

    event Unwrapped(uint256 amount);

    constructor(IWETH _weth, address _recipient) {
        weth = _weth;
        recipient = _recipient;
    }

    receive() external payable {}

    function unwrap() external {
        weth.withdraw(weth.balanceOf(address(this)));

        uint256 amount = address(this).balance;
        (bool success,) = recipient.call{value: amount}("");
        require(success, "send failed");

        emit Unwrapped(amount);
    }
}
