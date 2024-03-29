// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;


import "forge-std/Script.sol";
import "../../../src/FeeRouter/ArbChildToParentRewardRouter.sol";

contract DeployScript is Script {
    function run() public {
        address parentChainTarget = vm.envAddress("L1_TO_DAO_TIMELOCK_ROUTER");
        uint256 minDistributionIntervalSeconds = 7 days;

        vm.startBroadcast();
        ChildToParentRewardRouter router = new ArbChildToParentRewardRouter({
            _parentChainTarget: parentChainTarget,
            _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
            _parentChainTokenAddress: address(1),
             _childChainTokenAddress: address(1),
            _childChainGatewayRouter: address(1)
        });
        console.log("Deployed ChildToParentRewardRouter onto nova at");
        console.log(address(router));
        vm.stopBroadcast();
    }
}
