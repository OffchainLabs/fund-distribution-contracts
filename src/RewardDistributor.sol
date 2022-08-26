// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

error EmptyRecipients();
error InvalidRecipientGroup(bytes32 currentRecipientGroup, bytes32 providedRecipientGroup);
error OwnerFailedRecieve(address owner, address recipient, uint256 value);
error NonZeroBalance(uint256 value);

// CHRIS: TODO:
// 1. comments
// 2. add tests for the events
// 3. decide whether to have update functionality, or just a separate contract, tradeoffs:
//      pros:
//      1. save the call data (not so important on nova)
//      2. save the single sload
//      cons:
//      1. when updating the group need to do a 2 step update the contract then point it at the old one
// 3.b Add tests for update functionality if we decide to keep it
// 4. optimise gas a bit
// 5. remove the safety check at the end of the function?
// 6. Add tests to CI

contract RewardDistributor is Ownable {
    event OwnerRecieved(address owner, address recipient, uint256 value);
    event RecipientRecieved(address recipient, uint256 value);

    bytes32 public currentRecipientGroup;

    constructor(address[] memory recipients) Ownable() {
        setRecipients(recipients);
    }

    function updateRecipients(address[] memory currentRecipients, address[] memory newRecipients) public onlyOwner {
        sendAll(currentRecipients);
        setRecipients(newRecipients);
    }

    function distributeDues(address[] memory recipients) public {
        sendAll(recipients);
    }

    function setRecipients(address[] memory recipients) private {
        if (recipients.length == 0) {
            revert EmptyRecipients();
        }

        // create a committment to the recipient group and update current
        bytes32 recipientGroup = keccak256(abi.encodePacked(recipients));
        currentRecipientGroup = recipientGroup;
    }

    function sendAll(address[] memory recipients) private {
        if (recipients.length == 0) {
            revert EmptyRecipients();
        }

        bytes32 recipientGroup = keccak256(abi.encodePacked(recipients));
        if (recipientGroup != currentRecipientGroup) {
            revert InvalidRecipientGroup(currentRecipientGroup, recipientGroup);
        }

        uint256 dues = address(this).balance;
        if (dues > 0) {
            // send out the dues
            uint256 individualDues = dues / recipients.length;
            for (uint256 r; r < recipients.length; r++) {
                if (r == (recipients.length - 1)) {
                    // last lucky recipient gets the change
                    individualDues += dues % recipients.length;
                }

                // send the funds
                (bool success,) = recipients[r].call{value: individualDues, gas: 100000 }("");

                // if the funds failed to send we send them to the owner for safe keeping
                // then the owner will have the opportunity to distribute them out of band
                if (success) {
                    emit RecipientRecieved(recipients[r], individualDues);
                } else {
                    (bool ownerSuccess,) = owner().call{value: individualDues}("");
                    // if this is the case then revert and sort it out
                    if (!ownerSuccess) {
                        revert OwnerFailedRecieve(owner(), recipients[r], individualDues);
                    }

                    emit OwnerRecieved(owner(), recipients[r], individualDues);
                }
            }
        }

        // safety check that all was correctly sent
        if (address(this).balance != 0) {
            revert NonZeroBalance(address(this).balance);
        }
    }
}
