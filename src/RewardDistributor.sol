// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

error EmptyRecipients();
error InvalidRecipientGroup(bytes32 currentRecipientGroup, bytes32 providedRecipientGroup);
error OwnerFailedRecieve(address owner, address recipient, uint256 value);
error NonZeroBalance(uint256 value);
error InvalidBalance();

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
// 7. and an else and emit an event if there were no dues to deliver

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
        bytes32 recipientGroup;
        assembly{
            recipientGroup := keccak256(add(recipients, 32), mul(mload(recipients), 32))
        }
        currentRecipientGroup = recipientGroup;
    }

    function sendAll(address[] memory recipients) private {
        if (recipients.length == 0) {
            revert EmptyRecipients();
        }

        // cache currentRecipientGroup in memory
        bytes32 _currentRecipientGroup = currentRecipientGroup;
        bytes32 recipientGroup;
        assembly{
            recipientGroup := keccak256(add(recipients, 32), mul(mload(recipients), 32))
        }
        if (recipientGroup != _currentRecipientGroup) {
            revert InvalidRecipientGroup(_currentRecipientGroup, recipientGroup);
        }

        uint256 dues = address(this).balance;
        if (dues > 0) {
            // send out the dues
            uint256 individualDues;
            uint256 last_r;
            unchecked {
                // recipients.length cannot be 0
                individualDues = dues / recipients.length;
                last_r = recipients.length - 1;
            }
            for (uint256 r; r < recipients.length;) {
                if (r == last_r) {
                    // last lucky recipient gets the change
                    individualDues = address(this).balance;
                    if (individualDues == 0) {
                        // last recipient may reentrant into this function
                        // and distributed the whole balance already
                        revert InvalidBalance();
                    }
                }

                // send the funds
                (bool success,) = recipients[r].call{value: individualDues, gas: 100000}("");

                // if the funds failed to send we send them to the owner for safe keeping
                // then the owner will have the opportunity to distribute them out of band
                if (success) {
                    emit RecipientRecieved(recipients[r], individualDues);
                } else {
                    // cache owner in memory
                    address _owner = owner();
                    (bool ownerSuccess,) = _owner.call{value: individualDues}("");
                    // if this is the case then revert and sort it out
                    if (!ownerSuccess) {
                        revert OwnerFailedRecieve(_owner, recipients[r], individualDues);
                    }
                    emit OwnerRecieved(_owner, recipients[r], individualDues);
                }
                unchecked {
                    ++r;
                }
            }
        }

        // safety check that all was correctly sent
        if (address(this).balance != 0) {
            revert NonZeroBalance(address(this).balance);
        }
    }
}
