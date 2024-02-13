// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "./FundSourceAllower.sol";

///@notice Creates FundSourceAllower contracts of which it is the admin.
contract FundSourceAllowerAdmin is Ownable {
    bytes32 constant SALT_CONSTANT = keccak256("ARB_AEP");
    // address to which eth funds in fundSourceAllowers get transfered
    address public immutable ethDestination;

    // address to which tokens in fundSourceAllowers get transfered
    address public immutable tokenDestination;

    error NotAContract(address addr);

    event NewFundSourceAlowerCreated(address addr, uint256 indexed chainId);
    event ApprovedStateSet(bool approved, address allower);

    /// @param _owner initial address with affordances to create FundSourceAllowers and to toggle aprprovals
    /// @param _ethDestination address to which funds in created FundSourceAllower get transfered
    /// @param _tokenDestination address to which funds in created Erc20FundSourceAllower get transfered

    constructor(address _owner, address _ethDestination, address _tokenDestination) {
        _transferOwnership(_owner);
        ethDestination = _ethDestination;
        tokenDestination = _tokenDestination;
    }

    /// @notice create fund source allower
    /// @param _sourceChainId chain ID of fund source, or other unique identifier (used for bookkeeping)
    function createFundSourceAllower(uint256 _sourceChainId) external onlyOwner returns (address) {
        FundSourceAllower allower = new FundSourceAllower{salt: _getSalt(_sourceChainId)}(
            _sourceChainId, ethDestination, tokenDestination, address(this)
        );
        emit NewFundSourceAlowerCreated({addr: address(allower), chainId: _sourceChainId});
        return address(allower);
    }

    /// @notice Set approved for target allower; enables transfer of funds to destination
    function setApproved(address payable _allower) external onlyOwner {
        FundSourceAllower(_allower).setApproved();
        emit ApprovedStateSet(true, _allower);
    }

    /// @notice Set approved to false for target allower; disables transfer of funds to destination
    function setNotApproved(address payable _allower) external onlyOwner {
        FundSourceAllower(_allower).setNotApproved();
        emit ApprovedStateSet(false, _allower);
    }

    /// @notice determine address of a fund souce allower given an id
    /// @param _sourceChainId ID of fund source, or other unique identifier
    function getFundSourceAllowerCreate2Address(uint256 _sourceChainId) public view returns (address) {
        bytes32 salt = _getSalt(_sourceChainId);
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(FundSourceAllower).creationCode,
                abi.encode(_sourceChainId, ethDestination, tokenDestination, address(this))
            )
        );
        return Create2.computeAddress(salt, bytecodeHash);
    }

    function _getSalt(uint256 _sourceChainId) internal pure returns (bytes32) {
        return keccak256(abi.encode(_sourceChainId, SALT_CONSTANT));
    }
}
