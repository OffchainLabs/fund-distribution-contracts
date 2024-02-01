// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "./FundSourceAllower.sol";

contract FundSourceAllowerAdmin is Ownable {
    address immutable destination;

    event NewFundSourceAlowerCreated(
        address addr,
        address fundSender,
        uint256 indexed chainId
    );
    event ApprovedToggled(bool approved, address allower);

    constructor(address _owner, address _destination) {
        _transferOwnership(_owner);
        destination = _destination;
    }

    function createFundSourceAllower(
        address _fundSender,
        uint256 _sourceChainId
    ) external onlyOwner {
        FundSourceAllower allower = new FundSourceAllower{
            salt: _getSalt(_fundSender, _sourceChainId)
        }(_fundSender, _sourceChainId, destination, address(this));
        emit NewFundSourceAlowerCreated({
            addr: address(allower),
            fundSender: _fundSender,
            chainId: _sourceChainId
        });
    }

    function toggleApprove(address payable _allower) external onlyOwner {
        bool allowed = FundSourceAllower(_allower).toggleApproved();
        emit ApprovedToggled(allowed, _allower);
    }

    function getFundSourceAllowerCreate2Address(
        address _fundSender,
        uint256 _sourceChainId
    ) public view returns (address) {
        bytes32 salt = _getSalt(_fundSender, _sourceChainId);
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(FundSourceAllower).creationCode,
                abi.encode(
                    _fundSender,
                    _sourceChainId,
                    destination,
                    address(this)
                )
            )
        );
        return Create2.computeAddress(salt, bytecodeHash);
    }

    function _getSalt(
        address _fundSender,
        uint256 _sourceChainId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(_fundSender, _sourceChainId));
    }
}
