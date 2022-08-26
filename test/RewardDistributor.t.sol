// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// import "./src/RewardDistributor.sol";
import "../src/RewardDistributor.sol";
import "forge-std/Test.sol";

contract EmptyContract {}

contract UsesTooMuchGasContract {
    receive() external payable {
        // 1k iterations should use at least 100k gas
        uint256 j = 0;
        for (uint256 i; i < 1000; i++) {
            j++;
        }
    }
}

contract RewardDistributorTest is Test {
    address a = vm.addr(0x01);
    address b = vm.addr(0x02);
    address c = vm.addr(0x03);
    address owner = vm.addr(0x04);
    address nobody = vm.addr(0x05);

    function clearAccounts() public {
        vm.deal(a, 0);
        vm.deal(b, 0);
        vm.deal(c, 0);
        vm.deal(owner, 0);
        vm.deal(nobody, 0);
    }

    function makeRecipientGroup(uint256 count) private view returns (address[] memory) {
        address[] memory recipients = new address[](count);
        if (0 < count) {
            recipients[0] = a;
        }
        if (1 < count) {
            recipients[1] = b;
        }
        if (2 < count) {
            recipients[2] = c;
        }
        return recipients;
    }

    function testConstructor() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(3);

        vm.prank(owner);
        RewardDistributor rd = new RewardDistributor(recipients);

        assertEq(rd.currentRecipientGroup(), keccak256(abi.encodePacked(recipients)));
        assertEq(rd.owner(), owner);
    }

    function testConstructorDoesNotAcceptEmpty() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(0);

        vm.prank(owner);
        vm.expectRevert(EmptyRecipients.selector);
        new RewardDistributor(recipients);
    }

    // 1. does it distribute from non owner
    function testDistributeDues() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(3);

        vm.prank(owner);
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.prank(nobody);
        rd.distributeDues(recipients);

        uint256 aReward = reward / 3;
        assertEq(a.balance, aReward, "a balance");
        assertEq(b.balance, aReward, "b balance");
        assertEq(c.balance, aReward + reward % 3, "c balance");
        assertEq(owner.balance, 0, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
    }

    function testDistributeDuesDoesRefundsOwner() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(3);

        vm.prank(owner);
        RewardDistributor rd = new RewardDistributor(recipients);

        // the empty contract will revert when sending funds to it, as it doesn't
        // have a fallback. We set the c address to have this code
        UsesTooMuchGasContract ec = new UsesTooMuchGasContract();
        vm.etch(c, address(ec).code);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.prank(nobody);
        rd.distributeDues(recipients);

        uint256 aReward = reward / 3;
        assertEq(a.balance, aReward, "a balance");
        assertEq(b.balance, aReward, "b balance");
        assertEq(c.balance, 0, "c balance");
        assertEq(owner.balance, aReward + reward % 3, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
    }

    function testDistributeDuesDoesNotDistributeToEmpty() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(3);

        vm.prank(owner);
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.expectRevert(EmptyRecipients.selector);
        address[] memory emptyRecipients = makeRecipientGroup(0);
        vm.prank(nobody);
        rd.distributeDues(emptyRecipients);
    }

    // 4. does it check for correct recipients - different number, and one different value
    function testDistributeDuesDoesNotDistributeWrongRecipients() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(3);

        vm.prank(owner);
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory wrongRecipients = new address[](3);
        wrongRecipients[0] = a;
        wrongRecipients[1] = b;
        // wrong recipient
        wrongRecipients[2] = nobody;
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientGroup.selector, rd.currentRecipientGroup(), keccak256(abi.encodePacked(wrongRecipients))
            )
        );
        vm.prank(nobody);
        rd.distributeDues(wrongRecipients);
    }

    function testDistributeDuesDoesNotDistributeToWrongCount() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(3);

        vm.prank(owner);
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory shortRecipients = makeRecipientGroup(2);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientGroup.selector, rd.currentRecipientGroup(), keccak256(abi.encodePacked(shortRecipients))
            )
        );
        vm.prank(nobody);
        rd.distributeDues(shortRecipients);
    }

    function testDistributeDuesFailsToRefundsOwner() public {
        clearAccounts();
        address[] memory recipients = makeRecipientGroup(3);

        vm.prank(owner);
        RewardDistributor rd = new RewardDistributor(recipients);

        // the empty contract will revert when sending funds to it, as it doesn't
        // have a fallback. We set the c address and the owner to have this code
        EmptyContract ec = new EmptyContract();
        vm.etch(c, address(ec).code);
        vm.etch(owner, address(ec).code);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.expectRevert(abi.encodeWithSelector(OwnerFailedRecieve.selector, owner, c, (reward / 3) + reward % 3));
        vm.prank(nobody);
        rd.distributeDues(recipients);
    }
}
