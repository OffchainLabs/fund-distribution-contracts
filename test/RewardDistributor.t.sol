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

    modifier withContext(uint256 count) {
        recipients = makeRecipientGroup(count);
        weights = makeRecipientWeights(count);
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

    function makeRecipientWeights(uint256 count) private returns (uint256[] memory) {
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

    function testConstructor() public withContext(3) {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(zero, owner);
        vm.expectEmit(true, true, false, false);
        emit RecipientsUpdated(
            keccak256(abi.encodePacked(recipients)), recipients, keccak256(abi.encodePacked(weights)), weights
        );
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        assertEq(rd.currentRecipientGroup(), keccak256(abi.encodePacked(recipients)));
        assertEq(rd.owner(), owner);
    }

    function testConstructorDoesNotAcceptEmpty() public withContext(0) {
        vm.expectRevert(EmptyRecipients.selector);
        new RewardDistributor(recipients, weights);
    }

    function testConstructorDoesNotAcceptPastLimit() public withContext(65) {
        vm.expectRevert(TooManyRecipients.selector);
        new RewardDistributor(recipients, weights);
    }

    function testConstructorInputLengthMismatch() public withContext(3) {
        uint256[] memory shortWeights = new uint256[](2);
        shortWeights[0] = weights[0];
        shortWeights[1] = weights[1];
        vm.expectRevert(InputLengthMismatch.selector);
        new RewardDistributor(recipients, shortWeights);
    }

    function testUpdateDoesNotAcceptInvalidValues() public withContext(5) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory newRecipients;
        uint256[] memory newWeights;

        newRecipients = makeRecipientGroup(65);
        newWeights = makeRecipientWeights(65);
        vm.expectRevert(TooManyRecipients.selector);
        rd.distributeAndUpdateRecipients(recipients, weights, newRecipients, newWeights);

        newRecipients = makeRecipientGroup(0);
        newWeights = makeRecipientWeights(0);
        vm.expectRevert(EmptyRecipients.selector);
        rd.distributeAndUpdateRecipients(recipients, weights, newRecipients, newWeights);

        newRecipients = makeRecipientGroup(3);
        newWeights = makeRecipientWeights(2);
        vm.expectRevert(InputLengthMismatch.selector);
        rd.distributeAndUpdateRecipients(recipients, weights, newRecipients, newWeights);

        newRecipients = makeRecipientGroup(2);
        newWeights = makeRecipientWeights(3);
        vm.expectRevert(InputLengthMismatch.selector);
        rd.distributeAndUpdateRecipients(recipients, weights, newRecipients, newWeights);

        newRecipients = makeRecipientGroup(2);
        newWeights = new uint256[](2);
        newWeights[0] = 10000;
        newWeights[1] = 10000;
        vm.expectRevert(abi.encodeWithSelector(InvalidTotalWeight.selector, 20000));
        rd.distributeAndUpdateRecipients(recipients, weights, newRecipients, newWeights);
    }

    function testDistributeAndUpdateRecipients() public withContext(64) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory newRecipients = makeRecipientGroup(50);
        uint256[] memory newWeights = makeRecipientWeights(50);
        rd.distributeAndUpdateRecipients(recipients, weights, newRecipients, newWeights);
        assertEq(rd.currentRecipientGroup(), keccak256(abi.encodePacked(newRecipients)));

        assertEq(newRecipients[0].balance, reward / BASIS_POINTS * weights[0], "a balance before update");
        assertEq(newRecipients[1].balance, reward / BASIS_POINTS * weights[1], "b balance before update");
        assertEq(newRecipients[2].balance, reward / BASIS_POINTS * weights[2], "c balance before update");
        assertEq(owner.balance, 0, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertEq(reward % 64, 0, "remainder"); // test the code path without remainder
        assertEq(address(rd).balance, reward % BASIS_POINTS, "rewards balance");
    }

    function testDistributeAndUpdateRecipientsNotOwner() public withContext(64) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        vm.stopPrank();
        vm.startPrank(nobody);

        address[] memory newRecipients = makeRecipientGroup(50);
        uint256[] memory newWeights = makeRecipientWeights(50);

        // only owner should be able to call distributeRewards
        vm.expectRevert("Ownable: caller is not the owner");
        rd.distributeAndUpdateRecipients(recipients, weights, newRecipients, newWeights);
    }

    function testDistributeAndUpdateRecipientsBadPrevious() public withContext(64) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory newRecipients = makeRecipientGroup(50);
        uint256[] memory newWeights = makeRecipientWeights(50);

        // revert on wrong previous group
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientGroup.selector, rd.currentRecipientGroup(), keccak256(abi.encodePacked(newRecipients))
            )
        );
        rd.distributeAndUpdateRecipients(newRecipients, newWeights, newRecipients, newWeights);
    }

    address zero = 0x0000000000000000000000000000000000000000;

    function testDistributeRewards(uint256 reward) public withContext(3) {
        // If reward is less than recipient.length, we expect to throw an error
        // see testLowSend
        vm.assume(reward >= BASIS_POINTS);

        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // increase the balance of rd
        vm.deal(address(rd), reward);

        vm.expectEmit(true, false, false, true);
        emit RecipientRecieved(recipients[0], reward / BASIS_POINTS * weights[0]);
        vm.expectEmit(true, false, false, true);
        emit RecipientRecieved(recipients[1], reward / BASIS_POINTS * weights[1]);
        vm.expectEmit(true, false, false, true);
        emit RecipientRecieved(recipients[2], reward / BASIS_POINTS * weights[2]);

        vm.stopPrank();
        vm.startPrank(nobody);
        // anyone should be able to call distributeRewards
        rd.distributeRewards(recipients, weights);

        assertEq(recipients[0].balance, reward / BASIS_POINTS * weights[0], "a balance");
        assertEq(recipients[1].balance, reward / BASIS_POINTS * weights[1], "b balance");
        assertEq(recipients[2].balance, reward / BASIS_POINTS * weights[2], "c balance");
        assertEq(owner.balance, 0, "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertEq(address(rd).balance, reward % BASIS_POINTS, "rewards balance");
    }

    function testLowSend(uint256 rewards) public withContext(8) {
        vm.assume(rewards < BASIS_POINTS);

        RewardDistributor rd = new RewardDistributor(recipients, weights);

        vm.deal(address(rd), rewards);

        vm.expectRevert(NoFundsToDistribute.selector);
        rd.distributeRewards(recipients, weights);
    }

    function testDistributeRewardsDoesRefundsOwner(uint256 reward) public withContext(3) {
        vm.assume(reward >= BASIS_POINTS);
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // the empty contract will revert when sending funds to it, as it doesn't
        // have a fallback. We set the c address to have this code
        Reverter ec = new Reverter();
        vm.etch(recipients[2], address(ec).code);

        // increase the balance of rd
        vm.deal(address(rd), reward);

        vm.expectEmit(true, false, false, true);
        emit RecipientRecieved(recipients[0], reward / BASIS_POINTS * weights[0]);
        vm.expectEmit(true, false, false, true);
        emit RecipientRecieved(recipients[1], reward / BASIS_POINTS * weights[1]);
        vm.expectEmit(true, false, false, true);
        emit OwnerRecieved(owner, recipients[2], reward / BASIS_POINTS * weights[2]);

        rd.distributeRewards(recipients, weights);

        assertEq(recipients[0].balance, reward / BASIS_POINTS * weights[0], "a balance");
        assertEq(recipients[1].balance, reward / BASIS_POINTS * weights[1], "b balance");
        assertEq(recipients[2].balance, 0, "c balance");
        assertEq(owner.balance, reward / BASIS_POINTS * weights[2], "owner balance");
        assertEq(nobody.balance, 0, "nobody balance");
        assertEq(address(rd).balance, reward % BASIS_POINTS, "rewards balance");
    }

    function testDistributeRewardsDoesNotDistributeToEmpty() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.expectRevert(EmptyRecipients.selector);
        address[] memory emptyRecipients = makeRecipientGroup(0);
        uint256[] memory emptyWeights = makeRecipientWeights(0);

        rd.distributeRewards(emptyRecipients, emptyWeights);
    }

    function testDistributeRewardsDoesNotDistributeWrongRecipients() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

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
        rd.distributeRewards(wrongRecipients, weights);
    }

    function testDistributeRewardsDoesNotDistributeWrongWeights() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        uint256[] memory wrongWeights = new uint256[](3);
        wrongWeights[0] = 1;
        wrongWeights[1] = 2;
        wrongWeights[2] = 9997;
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientWeights.selector,
                rd.currentRecipientWeights(),
                keccak256(abi.encodePacked(wrongWeights))
            )
        );
        rd.distributeRewards(recipients, wrongWeights);
    }

    function testDistributeRewardsDoesNotDistributeToWrongCount() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        address[] memory shortRecipients = makeRecipientGroup(2);
        uint256[] memory shortWeights = makeRecipientWeights(2);
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientGroup.selector, rd.currentRecipientGroup(), keccak256(abi.encodePacked(shortRecipients))
            )
        );
        rd.distributeRewards(shortRecipients, shortWeights);
    }

    function testDistributeRewardsFailsToRefundsOwner() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);

        // the empty contract will revert when sending funds to it, as it doesn't
        // have a fallback. We set the c address and the owner to have this code
        Empty ec = new Empty();
        vm.etch(recipients[2], address(ec).code);
        vm.etch(owner, address(ec).code);

        // increase the balance of rd
        uint256 reward = 1e8;
        vm.deal(address(rd), reward);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnerFailedRecieve.selector, owner, recipients[2], (reward / BASIS_POINTS * weights[2])
            )
        );

        rd.distributeRewards(recipients, weights);
    }

    function testDistributeRewardsInputLengthMismatch() public withContext(3) {
        RewardDistributor rd = new RewardDistributor(recipients, weights);
        uint256[] memory shortWeights = new uint256[](2);
        shortWeights[0] = weights[0];
        shortWeights[1] = weights[1];
        vm.expectRevert(InputLengthMismatch.selector);
        rd.distributeRewards(recipients, shortWeights);
    }

    uint64 MAX_RECIPIENTS = 64;

    function testBlockGasLimit() public withContext(MAX_RECIPIENTS) {
        for (uint256 i = 0; i < recipients.length; i++) {
            recipients[i] = address(new Reverter());
        }
        RewardDistributor rd = new RewardDistributor(recipients, weights);
        assertEq(MAX_RECIPIENTS, rd.MAX_RECIPIENTS());

        uint256 rewards = 5 ether;
        vm.deal(address(rd), rewards);

        uint256 gasleftPrior = gasleft();
        rd.distributeRewards(recipients, weights);
        uint256 gasleftAfter = gasleft();
        uint256 gasUsed = gasleftPrior - gasleftAfter;

        uint256 targetBlockGasLimit = 16_000_000;
        // must fit within target block gas limit (this value may change in the future)
        // block.gaslimit >= PER_RECIPIENT_GAS * MAX_RECIPIENTS + SEND_ALL_FIXED_GAS
        assertGt(targetBlockGasLimit, gasUsed, "past target block gas limit");
        assertGe(gasUsed, rd.PER_RECIPIENT_GAS() * rd.MAX_RECIPIENTS(), "reverter contracts didnt use all gas");
        assertEq(address(owner).balance, rewards - (rewards % recipients.length), "owner didn't receive all funds");
    }

    function testHashAddresses() public {
        address[] memory input;
        bytes32 actual;
        bytes32 expected;

        // in practice reward distributor does not allow this to happen
        input = new address[](0);
        actual = hashAddresses(input);
        expected = bytes32(0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470);
        assertEq(actual, expected, "incorrect empty hash");

        input = new address[](1);
        input[0] = address(1);
        actual = hashAddresses(input);
        expected = bytes32(0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6);
        assertEq(actual, expected, "incorrect addr 1 hash");

        input = makeRecipientGroup(MAX_RECIPIENTS);
        actual = hashAddresses(input);
        expected = bytes32(0x95e9a53b9c4215b83ebc13939985ca72fe2424db3c861aa2b1bc741c56efabd0);
        assertEq(actual, expected, "incorrect max recipients hash");
    }

    function testUncheckedInc() public {
        uint256 expected;
        uint256 actual;

        expected = 1;
        actual = uncheckedInc(0);
        assertEq(actual, expected, "incorrect low num increment");

        expected = type(uint256).max;
        actual = uncheckedInc(type(uint256).max - 1);
        assertEq(actual, expected, "incorrect high num increment");

        expected = 0;
        actual = uncheckedInc(type(uint256).max);
        assertEq(actual, expected, "incorrect overflow increment");
    }
}
