// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @notice Accepts funds, calling `target` with `data` the first time it is paid.
/// @dev Keeps the call's returndata so a test can check how the nested call ended.
contract Reenterer {
    address target;
    bytes data;
    bool entered;
    bytes public returnData;

    function setCall(address _target, bytes memory _data) external {
        target = _target;
        data = _data;
    }

    receive() external payable {
        if (entered) {
            return;
        }
        entered = true;
        (, returnData) = target.call(data);
    }
}
