import "forge-std/Script.sol";
import "../../../src/FeeRouter/ChildToParentRewardRouter.sol";

contract DeployScript is Script {
    function run() public {
        // deployed via eth-deploy.s.sol:
        address parentChainTarget = vm.envAddress("L1_TO_DAO_TIMELOCK_ROUTER");
        uint256 minDistributionIntervalSeconds = 7 days;
        address childChainGatewayRouter = address(0x21903d3F8176b1a0c17E953Cd896610Be9fFDFa8);

        vm.startBroadcast();
        ChildToParentRewardRouter router = new ChildToParentRewardRouter({
            _parentChainTarget: parentChainTarget,
            _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
            _childChainGatewayRouter: IChildChainGatewayRouter(childChainGatewayRouter)
        });
        console.log("Deployed ChildToParentRewardRouter onto nova at");
        console.log(address(router));
        vm.stopBroadcast();
    }
}
