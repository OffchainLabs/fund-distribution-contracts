// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../../../src/FeeRouter/ArbChildToParentRewardRouter.sol";

contract DeployScript is Script {
    function run() public {
        // deployed via sepolia-deploy.s.sol
        //  address parentChainTarget = vm.envAddress("SEP_PARENT_CHAIN_TARGET");

        // uint256 minDistributionIntervalSeconds = 60;
        // address childChainGatewayRouter = 0x9fDD1C4E4AA24EEc1d913FABea925594a20d43C7;
        // vm.startBroadcast();
        // ArbChildToParentRewardRouter router = new ArbChildToParentRewardRouter({
        //     _parentChainTarget: parentChainTarget,
        //     _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
        //     _childChainGatewayRouter: IChildChainGatewayRouter(childChainGatewayRouter)
        // });
        // console.log("Deployed ArbChildToParentRewardRouter onto Arb Sepolia at");
        // console.log(address(router));
        // vm.stopBroadcast();
    }
}
