// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {hashAddresses, uncheckedInc} from "./Util.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

error TooManyRecipients();
error EmptyRecipients();
error InvalidRecipientGroup(bytes32 currentRecipientGroup, bytes32 providedRecipientGroup);
error OwnerFailedRecieve(address owner, address recipient, uint256 value);
error NoFundsToDistribute();

/// @title A distributor of ether
/// @notice You can use this contract to distribute ether evenly between a group of participants managed by an owner.
/// @dev If a particular recipient is not able to recieve funds at their address, the payment will fallback to the owner.
contract RewardDistributor is Ownable {
    /// @notice Amount of gas forwarded to each transfer call.
    /// @dev The recipient group is assumed to be a known group of contracts that won't consume more than this amount.
    uint256 public constant PER_RECIPIENT_GAS = 100_000;

    /// @notice The maximum number of addresses that may be recipients.
    /// @dev This ensures that all sends may always happen within a block.
    uint64 public constant MAX_RECIPIENTS = 64;

    /// @notice Hash of concat'ed recipient group.
    bytes32 public currentRecipientGroup;

    /// @notice The recipient couldn't receive rewards, so fallback to owner was triggered.
    event OwnerRecieved(address indexed owner, address indexed recipient, uint256 value);

    /// @notice Address successfully received rewards.
    event RecipientRecieved(address indexed recipient, uint256 value);

    /// @notice New recipients have been set
    event RecipientsUpdated(bytes32 recipientGroup, address[] recipients);

    /// @notice It is assumed that all recipients are able to receive eth when called with value but no data
    /// @param recipients Addresses to receive rewards.
    constructor(address[] memory recipients) Ownable() {
        setRecipients(recipients);
    }

    /// @notice allows eth to be deposited into this contract
    /// @dev this contract is expected to handle ether appearing in its balance as well as an explicit deposit
    receive() external payable {}

    /**
     * @notice Distributes previous rewards then updates the recipients to a new group.
     * @param currentRecipients Group of addresses that will receive their final rewards.
     * @param newRecipients Group of addresses that will receive future rewards.
     */
    function distributeAndUpdateRecipients(address[] memory currentRecipients, address[] memory newRecipients)
        external
        onlyOwner
    {
        distributeRewards(currentRecipients);
        setRecipients(newRecipients);
    }

    /**
     * @notice Sends rewards to the current group of recipients.
     * @dev The remainder will be kept in the contract.
     * @param recipients Group of addresses to receive rewards.
     */
    function distributeRewards(address[] memory recipients) public {
        if (recipients.length == 0) {
            revert EmptyRecipients();
        }

        bytes32 recipientGroup = hashAddresses(recipients);
        if (recipientGroup != currentRecipientGroup) {
            revert InvalidRecipientGroup(currentRecipientGroup, recipientGroup);
        }

        // calculate individual reward
        uint256 rewards = address(this).balance;
        uint256 individualRewards;
        unchecked {
            // recipients.length cannot be 0
            individualRewards = rewards / recipients.length;
        }
        if (individualRewards == 0) {
            revert NoFundsToDistribute();
        }
        for (uint256 r; r < recipients.length; r = uncheckedInc(r)) {
            // send the funds
            // if the recipient reentry to steal funds, the contract will not have sufficient
            // funds and revert when trying to send fund to the next recipient
            // if the recipient is the last, it doesn't matter since there are no extra fund to steal
            (bool success,) = recipients[r].call{value: individualRewards, gas: PER_RECIPIENT_GAS}("");

            // if the funds failed to send we send them to the owner for safe keeping
            // then the owner will have the opportunity to distribute them out of band
            if (success) {
                emit RecipientRecieved(recipients[r], individualRewards);
            } else {
                // cache owner in memory
                address _owner = owner();
                (bool ownerSuccess,) = _owner.call{value: individualRewards}("");
                // if this is the case then revert and sort it out
                // it's important that this fail in order to preserve the accounting in this contract.
                // if we dont fail here we enable a re-entrancy attack
                if (!ownerSuccess) {
                    revert OwnerFailedRecieve(_owner, recipients[r], individualRewards);
                }
                emit OwnerRecieved(_owner, recipients[r], individualRewards);
            }
        }
    }

    /**
     * @notice Validates and sets the group of recipient addresses. It is assumed that all recipients are able to receive eth
     * @dev We enforce a max number of recipients to ensure the distribution of rewards fits within a block.
     * @param recipients Group of addresses that will receive future rewards.
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
        bytes32 recipientGroup = hashAddresses(recipients);
        currentRecipientGroup = recipientGroup;

        emit RecipientsUpdated(recipientGroup, recipients);
    }
}
