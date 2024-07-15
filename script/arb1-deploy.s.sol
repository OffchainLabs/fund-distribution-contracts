// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/RewardDistributor.sol";

contract DeployScript is Script {
    address constant l2Executor = address(0xCF57572261c7c2BCF21ffD220ea7d1a27D40A827);
    address constant l2TreasuryTimelock = address(0xbFc1FECa8B09A5c5D3EFfE7429eBE24b9c09EF58);
    address constant l2OffchainLabsMultisig = address(0x98e4dB7e07e584F89A2F6043E7b7C89DC27769eD);

    function setUp() public {}

    function run() public {
        address[] memory recipients = new address[](1);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

        vm.startBroadcast();

        recipients[0] = l2TreasuryTimelock;
        RewardDistributor rd_l2base = new RewardDistributor({recipients: recipients, weights: weights});
        rd_l2base.transferOwnership(l2Executor);
        console.log("Deployed L2 Base at: ");
        console.log(address(rd_l2base));

        recipients[0] = l2TreasuryTimelock;
        RewardDistributor rd_l2surplus = new RewardDistributor({recipients: recipients, weights: weights});
        rd_l2surplus.transferOwnership(l2Executor);
        console.log("Deployed L2 Surplus at: ");
        console.log(address(rd_l2surplus));

        recipients[0] = l2OffchainLabsMultisig;
        RewardDistributor rd_l1base = new RewardDistributor({recipients: recipients, weights: weights});
        rd_l1base.transferOwnership(l2Executor);
        console.log("Deployed L1 Base at: ");
        console.log(address(rd_l1base));

        recipients[0] = l2TreasuryTimelock;
        RewardDistributor rd_l1surplus = new RewardDistributor({recipients: recipients, weights: weights});
        rd_l1surplus.transferOwnership(l2Executor);
        console.log("Deployed L1 Surplus at: ");
        console.log(address(rd_l1surplus));

        vm.stopBroadcast();
    }
}
