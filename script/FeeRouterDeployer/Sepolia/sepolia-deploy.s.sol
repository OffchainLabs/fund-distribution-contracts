// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../../../src/FeeRouter/ParentToChildRewardRouter.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        address arbSepoliaInbox = 0xaAe29B0366299461418F5324a79Afc425BE5ae21;

        // this is just an EOA:
        address arbSepoliaDestination = 0x7E43B9cE022f6127c739957550F94c64EC2A604A;

        uint256 minDistributionIntervalSeconds = 60;
        uint256 minGasPrice = 0.1 gwei;
        uint minGasLimit = 100_000;
        vm.startBroadcast();
        ParentToChildRewardRouter router = new ParentToChildRewardRouter({
            _inbox: arbSepoliaInbox,
            _destination: arbSepoliaDestination,
            _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
            _minGasPrice: minGasPrice,
            _minGasLimit: minGasLimit
        });

        console.log("Deployed ParentToChildRewardRouter onto Sepolia at");
        console.log(address(router));
        vm.stopBroadcast();
    }
}
