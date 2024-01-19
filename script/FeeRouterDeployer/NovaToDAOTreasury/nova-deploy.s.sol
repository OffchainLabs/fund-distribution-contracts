import "forge-std/Script.sol";
import "../../../src/FeeRouter/ChildToParentRewardRouter.sol";

contract DeployScript is Script {
    function run() public {
        // deployed via eth-deploy.s.sol:
        address parentChainTarget = vm.envAddress("L1_TO_DAO_TIMELOCK_ROUTER");
        uint256 minDistributionIntervalSeconds = 7 days;
        vm.startBroadcast();
        ChildToParentRewardRouter router = new ChildToParentRewardRouter({
            _parentChainTarget: parentChainTarget,
            _minDistributionIntervalSeconds: minDistributionIntervalSeconds
        });
        console.log("Deployed ChildToParentRewardRouter onto nova at");
        console.log(address(router));
        vm.stopBroadcast();
    }
}
