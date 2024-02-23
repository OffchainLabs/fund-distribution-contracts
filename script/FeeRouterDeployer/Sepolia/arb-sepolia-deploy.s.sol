import "forge-std/Script.sol";
import "../../../src/FeeRouter/ChildToParentRewardRouter.sol";

contract DeployScript is Script {
    function run() public {
        // deployed via sepolia-deploy.s.sol
        address parentChainTarget = 0xbFC9513A767F226a5878072E1D7C3bF663D9e297;
        uint256 minDistributionIntervalSeconds = 60;
        address childChainGatewayRouter = address(0x9fDD1C4E4AA24EEc1d913FABea925594a20d43C7);
        vm.startBroadcast();
        ChildToParentRewardRouter router = new ChildToParentRewardRouter({
            _parentChainTarget: parentChainTarget,
            _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
            _childChainGatewayRouter: IChildChainGatewayRouter(childChainGatewayRouter)
        });
        console.log("Deployed ChildToParentRewardRouter onto Arb Sepolia at");
        console.log(address(router));
        vm.stopBroadcast();
    }
}
