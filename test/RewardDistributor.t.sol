// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// import "./src/RewardDistributor.sol";
import "../src/RewardDistributor.sol";
import "./Reverter.sol";
import "./Empty.sol";
import "forge-std/Test.sol";

contract RewardDistributorTest is Test {
    event OwnerRecieved(address indexed owner, address indexed recipient, uint256 value);
    event RecipientRecieved(address indexed recipient, uint256 value);
    event RecipientsUpdated(bytes32 recipientGroup, address[] recipients, bytes32 recipientWeights, uint256[] weights);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address owner = vm.addr(0x04);
    address nobody = vm.addr(0x05);
    address[] recipients;
    uint256[] weights;
    RewardDistributor rd;


    function setUp() public {
        recipients = makeRecipientGroup(3);
        weights = makeRecipientWeights(3);
        // clear accounts
        vm.deal(owner, 0);
        vm.deal(nobody, 0);

        // set owner as caller before execution
        vm.startPrank(owner);

        rd = new RewardDistributor(recipients, weights);
    }

    function makeRecipientGroup(uint256 count) private returns (address[] memory) {
        address[] memory recps = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            // offset to avoid collision with a/b/c/owner/nobody
            recps[i] = vm.addr(i + 105);
            vm.deal(recps[i], 0);
        }
        return recps;
    }

    function makeRecipientWeights(uint256 count) private pure returns (uint256[] memory) {
        uint256[] memory weig = new uint256[](count);
        if (count == 0) {
            return weig;
        }
        uint256 even = BASIS_POINTS / count;
        for (uint256 i = 0; i < count; i++) {
            weig[i] = even;
        }
        weig[count - 1] += BASIS_POINTS - (even * (count));
        return weig;
    }
}
