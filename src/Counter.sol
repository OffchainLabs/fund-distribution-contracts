// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

error EmptyRecipients();
error InvalidRecipientGroup(bytes32 currentRecipientGroup, bytes32 providedRecipientGroup);
error OwnerFailedRecieve(address owner, uint256 value);
error NonZeroBalance(uint256 value);

contract DACPayout2 is Ownable {
    bytes32 currentRecipientGroup;

    constructor(address[] memory recipients) Ownable() {
        setRecipients(recipients);
    }

    function updateRecipients(address [] memory currentRecipients, address[] memory newRecipients) public onlyOwner {
        sendAll(currentRecipients);
        setRecipients(newRecipients);
    }

    // CHRIS: TODO: should this be onlyOwner? anyone should be allowed to call this? could cause accounting issues?
    function distributeDues(address[] memory recipients) public onlyOwner {
        sendAll(recipients);
    }

    function setRecipients(address[] memory recipients) private {
        if(recipients.length == 0) revert EmptyRecipients();

        // create a committment to the recipient group and update current
        bytes32 recipientGroup = keccak256(abi.encodePacked(recipients));
        currentRecipientGroup = recipientGroup;
    }

    function sendAll(address[] memory recipients) private {
        if(recipients.length == 0) revert EmptyRecipients();

        bytes32 recipientGroup = keccak256(abi.encodePacked(recipients));
        if(recipientGroup != currentRecipientGroup) revert InvalidRecipientGroup(currentRecipientGroup, recipientGroup);

        uint256 dues = address(this).balance;
        if(dues > 0) {
            // send out the dues
            uint256 individualDues = dues / recipients.length;
            for(uint256 r; r < recipients.length; r++) {
                if(r == (recipients.length - 1)) {
                    // last lucky recipient gets the change
                    individualDues += dues % recipients.length;
                }

                // send the funds
                // CHRIS: TODO: should we set a gas stipend here? In theory a malicious contract can stop the whole payout occuring
                // CHRIS: TODO: if they do that we cant update the set since we always pay out before update
                (bool success, ) = recipients[r].call{ value: individualDues }("");

                // if the funds failed to send we send them to the owner for safe keeping
                // then the owner will have the opportunity to distribute them out of band
                if(!success) {
                    // CHRIS: TODO: is this the only way to access owner?
                    (bool ownerSuccess, ) = owner().call{ value: individualDues }("");
                    // if this is the case then revert and sort it out
                    if(!ownerSuccess) revert OwnerFailedRecieve(owner(), individualDues);
                }
            }
        }

        // safety check that all was correctly sent
        if(address(this).balance != 0) revert NonZeroBalance(address(this).balance);
    }
}
