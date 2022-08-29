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
    address a = vm.addr(0x01);
    address b = vm.addr(0x02);
    address c = vm.addr(0x03);
    // TODO: add test where owner is a gnosis safe?
    address owner = vm.addr(0x04);
    address nobody = vm.addr(0x05);

    modifier withContext() {
        // clear accounts
        vm.deal(a, 0);
        vm.deal(b, 0);
        vm.deal(c, 0);
        vm.deal(owner, 0);
        vm.deal(nobody, 0);

        // set owner as caller before execution
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function makeRecipientGroup(uint256 count) private returns (address[] memory) {
        address[] memory recipients = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            recipients[i] = vm.addr(i + 1);
        }
        return recipients;
    }

    function testConstructor() public withContext {
        address[] memory recipients = makeRecipientGroup(3);

        RewardDistributor rd = new RewardDistributor(recipients);

        assertEq(rd.currentRecipientGroup(), keccak256(abi.encodePacked(recipients)));
        assertEq(rd.owner(), owner);
    }

    function testConstructorDoesNotAcceptEmpty() public withContext {
        address[] memory recipients = makeRecipientGroup(0);
        vm.expectRevert(EmptyRecipients.selector);
        new RewardDistributor(recipients);
    }

    function testConstructorDoesNotAcceptPastLimit() public withContext {
        address[] memory recipients = makeRecipientGroup(65);
        vm.expectRevert(TooManyRecipients.selector);
        new RewardDistributor(recipients);
    }

    function testDistributeRewards() public withContext {
        address[] memory recipients = makeRecipientGroup(3);

        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        rd.distributeRewards(recipients);

        uint256 aReward = reward / 3;
        assertEq(a.balance, aReward, "a balance");
        assertEq(b.balance, aReward, "b balance");
        assertEq(c.balance, aReward + reward % 3, "c balance");
        assertEq(owner.balance, 0, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertEq(address(rd).balance, 0, "rewards balance");
    }

    function testDistributeRewardsDoesRefundsOwner() public withContext {
        address[] memory recipients = makeRecipientGroup(3);

        RewardDistributor rd = new RewardDistributor(recipients);

        // the empty contract will revert when sending funds to it, as it doesn't
        // have a fallback. We set the c address to have this code
        UsesTooMuchGasContract ec = new UsesTooMuchGasContract();
        vm.etch(c, address(ec).code);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        rd.distributeRewards(recipients);

        uint256 aReward = reward / 3;
        assertEq(a.balance, aReward, "a balance");
        assertEq(b.balance, aReward, "b balance");
        assertEq(c.balance, 0, "c balance");
        assertEq(owner.balance, aReward + reward % 3, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertEq(address(rd).balance, 0, "rewards balance");
    }

    function testDistributeRewardsDoesNotDistributeToEmpty() public withContext {
        address[] memory recipients = makeRecipientGroup(3);

        RewardDistributor rd = new RewardDistributor(recipients);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.expectRevert(EmptyRecipients.selector);
        address[] memory emptyRecipients = makeRecipientGroup(0);

        rd.distributeRewards(emptyRecipients);
    }

    function testDistributeRewardsDoesNotDistributeWrongRecipients() public withContext {
        address[] memory recipients = makeRecipientGroup(3);

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
        rd.distributeRewards(wrongRecipients);
    }

    function testDistributeRewardsDoesNotDistributeToWrongCount() public withContext {
        address[] memory recipients = makeRecipientGroup(3);

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

    function testDistributeRewardsFailsToRefundsOwner() public withContext {
        address[] memory recipients = makeRecipientGroup(3);

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

        rd.distributeRewards(recipients);
    }

    function testBlockGasLimit() public withContext {
        uint64 numReverters = 64;
        address[] memory recipients = new address[](numReverters);
        for (uint256 i = 0; i < recipients.length; i++) {
            recipients[i] = address(new Reverter());
        }
        RewardDistributor rd = new RewardDistributor(recipients);

        assertEq(numReverters, rd.MAX_RECIPIENTS());

        // TODO: fuzz this value?
        uint256 rewards = 5 ether;
        vm.deal(address(rd), rewards);

        uint256 gasleftPrior = gasleft();
        emit log_named_uint("gas left prior", gasleftPrior);

        rd.distributeRewards(recipients);

        uint256 gasleftAfter = gasleft();
        emit log_named_uint("gas left after", gasleftAfter);

        uint256 gasUsed = gasleftPrior - gasleftAfter;
        emit log_named_uint("gas left used", gasUsed);

        uint256 blockGasLimit = 32_000_000;
        // must fit within block gas limit (this value may change in the future)
        // block.gaslimit >= PER_RECIPIENT_GAS * MAX_RECIPIENTS + SEND_ALL_FIXED_GAS
        assertGt(blockGasLimit, gasUsed, "past block gas limit");
        assertGe(gasUsed, rd.PER_RECIPIENT_GAS() * rd.MAX_RECIPIENTS(), "reverter contracts didnt use all gas");
        assertEq(address(owner).balance, rewards, "owner didn't receive all funds");
    }

    function testLowSend() public withContext {
        uint256 numRecipients = 8;
        address[] memory recipients = makeRecipientGroup(numRecipients);

        RewardDistributor rd = new RewardDistributor(recipients);

        uint256 rewards = 6;
        assertGt(numRecipients, rewards, "test not configured correctly");

        vm.deal(address(rd), rewards);

        rd.distributeRewards(recipients);

        for (uint256 i = 0; i < numRecipients; i++) {
            bool isLast = i == numRecipients - 1;
            uint256 expectedBalance = isLast ? rewards : 0;
            assertEq(recipients[i].balance, expectedBalance, "expected reward incorrect");
        }
    }
}
