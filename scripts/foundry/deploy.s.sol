// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/RewardDistributor.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        address[] memory recipients = new address[](1);
        recipients[0] = msg.sender;

        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        vm.startBroadcast();
        RewardDistributor rd = new RewardDistributor({recipients: recipients, weights: weights});
        console.log("Deployed RewardDistributor at: ");
        console.log(address(rd));
        vm.stopBroadcast();
    }
}
