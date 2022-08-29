// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// import "./src/RewardDistributor.sol";
import "../src/RewardDistributor.sol";
import "./Reverter.sol";
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
    address owner = vm.addr(0x04);
    address nobody = vm.addr(0x05);
    address[] recipients;

    modifier withContext(uint256 count) {
        recipients = makeRecipientGroup(count);
        // clear accounts
        vm.deal(owner, 0);
        vm.deal(nobody, 0);

        // set owner as caller before execution
        vm.startPrank(owner);
        _;
        vm.stopPrank();
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

    function testConstructor() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients);

        assertEq(rd.currentRecipientGroup(), keccak256(abi.encodePacked(recipients)));
        assertEq(rd.owner(), owner);
    }

    function testConstructorDoesNotAcceptEmpty() public withContext(0) {
        vm.expectRevert(EmptyRecipients.selector);
        new RewardDistributor(recipients);
    }

    function testConstructorDoesNotAcceptPastLimit() public withContext(65) {
        vm.expectRevert(TooManyRecipients.selector);
        new RewardDistributor(recipients);
    }

    function testDistributeRewards() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.stopPrank();
        vm.startPrank(nobody);
        // anyone should be able to call distributeRewards
        rd.distributeRewards(recipients);

        uint256 aReward = reward / 3;
        assertEq(recipients[0].balance, aReward, "a balance");
        assertEq(recipients[1].balance, aReward, "b balance");
        assertEq(recipients[2].balance, aReward, "c balance");
        assertEq(owner.balance, 0, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertGt(reward % 3, 0, "remainder"); // test the code path with remainder
        assertEq(address(rd).balance, reward % 3, "rewards balance");
    }

    function testDistributeAndUpdateRecipients() public withContext(50) {
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory many_recipients = makeRecipientGroup(50);
        rd.distributeAndUpdateRecipients(recipients, many_recipients);

        vm.stopPrank();
        vm.startPrank(nobody);

        // only owner should be able to call distributeRewards
        vm.expectRevert("Ownable: caller is not the owner");
        rd.distributeAndUpdateRecipients(many_recipients, recipients);

        // anyone should be able to call distributeRewards
        rd.distributeRewards(many_recipients);

        uint256 aReward = reward / 50;
        assertEq(many_recipients[0].balance, aReward, "a balance");
        assertEq(many_recipients[1].balance, aReward, "b balance");
        assertEq(many_recipients[2].balance, aReward, "c balance");
        assertEq(owner.balance, 0, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertEq(reward % 50, 0, "remainder"); // test the code path without remainder
        assertEq(address(rd).balance, reward % 50, "rewards balance");
    }

    function testDistributeRewardsDoesRefundsOwner() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients);

        // the empty contract will revert when sending funds to it, as it doesn't
        // have a fallback. We set the c address to have this code
        UsesTooMuchGasContract ec = new UsesTooMuchGasContract();
        vm.etch(recipients[2], address(ec).code);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        rd.distributeRewards(recipients);

        uint256 aReward = reward / 3;

        assertEq(recipients[0].balance, aReward, "a balance");
        assertEq(recipients[1].balance, aReward, "b balance");
        assertEq(recipients[2].balance, 0, "c balance");
        assertEq(owner.balance, aReward, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertEq(address(rd).balance, reward % 3, "rewards balance");
    }

    function testDistributeRewardsDoesNotDistributeToEmpty() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.expectRevert(EmptyRecipients.selector);
        address[] memory emptyRecipients = makeRecipientGroup(0);

        rd.distributeRewards(emptyRecipients);
    }

    function testDistributeRewardsDoesNotDistributeWrongRecipients() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory wrongRecipients = new address[](3);
        wrongRecipients[0] = recipients[0];
        wrongRecipients[1] = recipients[1];
        // wrong recipient
        wrongRecipients[2] = nobody;
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientGroup.selector, rd.currentRecipientGroup(), keccak256(abi.encodePacked(wrongRecipients))
            )
        );
        rd.distributeRewards(wrongRecipients);
    }

    function testDistributeRewardsDoesNotDistributeToWrongCount() public withContext(3) {
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
        rd.distributeRewards(shortRecipients);
    }

    function testDistributeRewardsFailsToRefundsOwner() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients);

        // the empty contract will revert when sending funds to it, as it doesn't
        // have a fallback. We set the c address and the owner to have this code
        EmptyContract ec = new EmptyContract();
        vm.etch(recipients[2], address(ec).code);
        vm.etch(owner, address(ec).code);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.expectRevert(abi.encodeWithSelector(OwnerFailedRecieve.selector, owner, recipients[2], (reward / 3)));

        rd.distributeRewards(recipients);
    }

    uint64 numReverters = 64;

    function testBlockGasLimit() public withContext(numReverters) {
        for (uint256 i = 0; i < recipients.length; i++) {
            recipients[i] = address(new Reverter());
        }
        RewardDistributor rd = new RewardDistributor(recipients);

        assertEq(numReverters, rd.MAX_RECIPIENTS());

        // TODO: fuzz this value?
        uint256 rewards = 5 ether;
        vm.deal(address(rd), rewards);

        uint256 gasleftPrior = gasleft();

        rd.distributeRewards(recipients);

        uint256 gasleftAfter = gasleft();
        uint256 gasUsed = gasleftPrior - gasleftAfter;

        uint256 targetBlockGasLimit = 16_000_000;
        // must fit within target block gas limit (this value may change in the future)
        // block.gaslimit >= PER_RECIPIENT_GAS * MAX_RECIPIENTS + SEND_ALL_FIXED_GAS
        assertGt(targetBlockGasLimit, gasUsed, "past target block gas limit");
        assertGe(gasUsed, rd.PER_RECIPIENT_GAS() * rd.MAX_RECIPIENTS(), "reverter contracts didnt use all gas");
        assertEq(address(owner).balance, rewards, "owner didn't receive all funds");
    }

    uint256 numRecipients = 8;

    function testLowSend() public withContext(8) {
        RewardDistributor rd = new RewardDistributor(recipients);
        uint256 rewards = 6;
        assertGt(numRecipients, rewards, "test not configured correctly");

        vm.deal(address(rd), rewards);

        rd.distributeRewards(recipients);

        for (uint256 i = 0; i < numRecipients; i++) {
            uint256 expectedBalance = 0;
            assertEq(recipients[i].balance, expectedBalance, "expected reward incorrect");
        }
    }
}
