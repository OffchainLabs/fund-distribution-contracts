// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../../../src/FeeRouter/ParentToChildRewardRouter.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // on L1:
        address novaInbox = 0xc4448b71118c9071Bcb9734A0EAc55D18A153949;
        // on Arb One:
        address daoTreasuryTimelock = 0xbFc1FECa8B09A5c5D3EFfE7429eBE24b9c09EF58;

        uint256 minDistributionIntervalSeconds = 7 days;
        uint256 minGasPrice = 0.1 gwei;
        uint minGasLimit = 120_000;
        vm.startBroadcast();
        ParentToChildRewardRouter router = new ParentToChildRewardRouter({
            _inbox: novaInbox,
            _destination: daoTreasuryTimelock,
            _minDistributionIntervalSeconds: minDistributionIntervalSeconds,
            _minGasPrice: minGasPrice,
            _minGasLimit: minGasLimit
        });

        console.log("Deployed ParentToChildRewardRouter onto Ethereum at");
        console.log(address(router));
        vm.stopBroadcast();
    }
}
