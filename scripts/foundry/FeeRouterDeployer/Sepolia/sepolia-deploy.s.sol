// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "contracts/FeeRouter/ParentToChildRewardRouter.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        address parentChainGatewayRouter = address(0xcE18836b233C83325Cc8848CA4487e94C6288264);

        // this is just an EOA:
        address arbSepoliaDestination = 0x7E43B9cE022f6127c739957550F94c64EC2A604A;

        uint256 minDistributionIntervalSeconds = 60;
        uint256 minGasPrice = 0.1 gwei;
        uint256 minGasLimit = 100_000;
        vm.startBroadcast();
        ParentToChildRewardRouter router = new ParentToChildRewardRouter({
            _destination: arbSepoliaDestination,
            _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
            _minGasPrice: minGasPrice,
            _minGasLimit: minGasLimit,
            _parentChainGatewayRouter: IParentChainGatewayRouter(parentChainGatewayRouter)
        });

        console.log("Deployed ParentToChildRewardRouter onto Sepolia at");
        console.log(address(router));
        vm.stopBroadcast();
    }
}
