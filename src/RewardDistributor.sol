// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

error TooManyRecipients();
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
// 7. and an else and emit an event if there were no rewards to deliver

contract RewardDistributor is Ownable {
    /// @notice the recipient couldn't receive rewards, so fallback to owner was triggered
    event OwnerRecieved(address owner, address recipient, uint256 value);

    /// @notice address successfully received rewards
    event RecipientRecieved(address recipient, uint256 value);

    /// @notice amount of gas forwarded to each transfer call
    /// @dev the recipient group is assumed to be a known set of contracts that won't consume more than this amount
    uint256 constant public PER_RECIPIENT_GAS = 100_000;
    
    /// @notice the maximum number of addresses that may be recipients
    /// @dev this ensures that all sends may always happen within a block
    uint64 constant public MAX_RECIPIENTS = 64;

    /// @notice hash of concat'ed recipient group
    bytes32 public currentRecipientGroup;

    /// @param recipients addresses to receive rewards
    constructor(address[] memory recipients) Ownable() {
        setRecipients(recipients);
    }

    /**
     * @notice validates and sets the set of recipient addresses
     * @dev we enforce a max number of recipients to ensure the distribution of rewards fits within a block
     * @param recipients set of addresses that will receive future rewards
     */
    function setRecipients(address[] memory recipients) private {
        if (recipients.length == 0) {
            revert EmptyRecipients();
        }
        if (recipients.length > MAX_RECIPIENTS) {
            // it is expected that all sends may happen within the block gas limit
            revert TooManyRecipients();
        }

        // create a committment to the recipient group and update current
        bytes32 recipientGroup = keccak256(abi.encodePacked(recipients));
        currentRecipientGroup = recipientGroup;
    }

    /**
     * @notice Distributes previous rewards then updates the recipients to a new set
     * @param currentRecipients set of addresses that will receive their final rewards 
     * @param newRecipients set of addresses that will receive future rewards
     */
    function distributeAndUpdateRecipients(address[] memory currentRecipients, address[] memory newRecipients) public onlyOwner {
        distributeRewards(currentRecipients);
        setRecipients(newRecipients);
    }


    /**
     * @notice sends rewards to the set of recipients
     * @dev it is assumed that PER_RECIPIENT_GAS * MAX_RECIPIENTS covers the dynamic cost of falling back to sending to the owner
     * @dev the last recipient gets the leftover dust 
     * @param recipients set of addresses to receive rewards
     */
    function distributeRewards(address[] memory recipients) public {
        if (recipients.length == 0) {
            revert EmptyRecipients();
        }

        bytes32 recipientGroup = keccak256(abi.encodePacked(recipients));
        if (recipientGroup != currentRecipientGroup) {
            revert InvalidRecipientGroup(currentRecipientGroup, recipientGroup);
        }

        uint256 rewards = address(this).balance;
        if (rewards > 0) {
            // send out the rewards
            uint256 individualRewards = rewards / recipients.length;
            for (uint256 r; r < recipients.length; r++) {
                if (r == (recipients.length - 1)) {
                    // last lucky recipient gets the change
                    individualRewards += rewards % recipients.length;
                }

                // send the funds
                (bool success,) = recipients[r].call{value: individualRewards, gas: PER_RECIPIENT_GAS}("");

                // if the funds failed to send we send them to the owner for safe keeping
                // then the owner will have the opportunity to distribute them out of band
                if (success) {
                    emit RecipientRecieved(recipients[r], individualRewards);
                } else {
                    (bool ownerSuccess,) = owner().call{value: individualRewards}("");
                    // if this is the case then revert and sort it out
                    if (!ownerSuccess) {
                        revert OwnerFailedRecieve(owner(), recipients[r], individualRewards);
                    }
                    emit OwnerRecieved(owner(), recipients[r], individualRewards);
                }
            }
        }

        // safety check that all was correctly sent
        if (address(this).balance != 0) {
            revert NonZeroBalance(address(this).balance);
        }
    }
}
