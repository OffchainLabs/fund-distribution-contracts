// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import "../src/RewardDistributor.sol";

contract DeployScript is Script {

    address constant l2ExecutorNova = address(0x86a02dD71363c440b21F4c0E5B2Ad01Ffe1A7482);
    // address constant l2TreasuryTimelockNova = address();
    address constant l2OffchainLabsMultisigNova = address(0xD0749b3e537Ed52DE4e6a3Ae1eB6fc26059d0895);
    
    // l1Timelock is 0xE6841D92B0C345144506576eC13ECf5103aC7f49
    address constant l1TimelockAlias = address(0xf7951D92B0C345144506576eC13Ecf5103aC905a);

    address constant MultiSigForGoogleCloud = address(0x41C327d5fc9e29680CcD45e5E52446E0DB3DAdFd);
    address constant QuickNode = address(0x02C2599aa929e2509741b44F3a13029745aB1AB2);
    address constant Consensys = address(0xA221f29236996BDEfA5C585acdD407Ec84D78447);
    address constant P2P = address(0x0fB1f1a31429F1A90a19Ab5486a6DFb384179641);
    address constant Opensea = address(0xb814441ed86e98e8B83d31eEC095e4a5A36Fc3c2);

    function setUp() public {}

    function run() public {
        address[] memory recipients;
        uint256[] memory weights;

        vm.startBroadcast();

        recipients = new address[](7);
        weights = new uint256[](7);
        recipients[0] = l1TimelockAlias; // Should be the DAO Treasury
        weights[0] = 8000;
        recipients[1] = l2OffchainLabsMultisigNova;
        weights[1] = 375;
        recipients[2] = MultiSigForGoogleCloud;
        weights[2] = 373;
        recipients[3] = QuickNode;
        weights[3] = 373;
        recipients[4] = Consensys;
        weights[4] = 373;
        recipients[5] = P2P;
        weights[5] = 373;
        recipients[6] = Opensea;
        weights[6] = 133;
        RewardDistributor rd_l2base = new RewardDistributor({
            recipients: recipients,
            weights: weights
        });
        rd_l2base.transferOwnership(l2ExecutorNova);
        console.log("Deployed Nova L2 Base at: ");
        console.log(address(rd_l2base));

        recipients = new address[](1);
        weights = new uint256[](1);
        weights[0] = 10000;

        recipients[0] = l1TimelockAlias;
        RewardDistributor rd_l2surplus = new RewardDistributor({
            recipients: recipients,
            weights: weights
        });
        rd_l2surplus.transferOwnership(l2ExecutorNova);
        console.log("Deployed Nova L2 Surplus at: ");
        console.log(address(rd_l2surplus));

        recipients[0] = l2OffchainLabsMultisigNova;
        RewardDistributor rd_l1base = new RewardDistributor({
            recipients: recipients,
            weights: weights
        });
        rd_l1base.transferOwnership(l2ExecutorNova);
        console.log("Deployed Nova L1 Base at: ");
        console.log(address(rd_l1base));

        recipients[0] = l1TimelockAlias;
        RewardDistributor rd_l1surplus = new RewardDistributor({
            recipients: recipients,
            weights: weights
        });
        rd_l1surplus.transferOwnership(l2ExecutorNova);
        console.log("Deployed Nova L1 Surplus at: ");
        console.log(address(rd_l1surplus));

        vm.stopBroadcast();
    }
}
