// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "./FundSourceAllower/Erc20FundSourceAllower.sol";
import "./FundSourceAllower/NativeFundSourceAllower.sol";

///@notice Creates FundSourceAllower contracts of which it is the admin of.
/// FundSourceAllower
contract FundSourceAllowerAdmin is Ownable {
    address immutable destination;

    event NewFundSourceAlowerCreated(
        address addr,
        uint256 indexed chainId,
        address indexed token
    );
    event ApprovedToggled(bool approved, address allower);

    constructor(address _owner, address _destination) {
        _transferOwnership(_owner);
        destination = _destination;
    }

    function createNativeFundSourceAllower(
        uint256 _sourceChainId
    ) external onlyOwner {
        NativeFundSourceAllower allower = new NativeFundSourceAllower{
            salt: _getSalt(_sourceChainId, address(0))
        }(_sourceChainId, destination, address(this));
        emit NewFundSourceAlowerCreated({
            addr: address(allower),
            chainId: _sourceChainId,
            token: address(0)
        });
    }

    function createErc20FundSourceAllower(
        uint256 _sourceChainId,
        address _token
    ) external onlyOwner {
        Erc20FundSourceAllower allower = new Erc20FundSourceAllower{
            salt: _getSalt(_sourceChainId, _token)
        }(_sourceChainId, destination, address(this), _token);
        emit NewFundSourceAlowerCreated({
            addr: address(allower),
            chainId: _sourceChainId,
            token: _token
        });
    }

    function toggleApprove(address payable _allower) external onlyOwner {
        bool allowed = FundSourceAllowerBase(_allower).toggleApproved();
        emit ApprovedToggled(allowed, _allower);
    }

    function getNativeFundSourceAllowerCreate2Address(
        uint256 _sourceChainId
    ) public view returns (address) {
        bytes32 salt = _getSalt(_sourceChainId, address(0));
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(NativeFundSourceAllower).creationCode,
                abi.encode(_sourceChainId, destination, address(this))
            )
        );
        return Create2.computeAddress(salt, bytecodeHash);
    }

    function getErc20FundSourceAllowerCreate2Address(
        uint256 _sourceChainId,
        address _token
    ) public view returns (address) {
        bytes32 salt = _getSalt(_sourceChainId, _token);
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(Erc20FundSourceAllower).creationCode,
                abi.encode(_sourceChainId, destination, address(this), _token)
            )
        );
        return Create2.computeAddress(salt, bytecodeHash);
    }

    function _getSalt(
        uint256 _sourceChainId,
        address token
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(_sourceChainId, token));
    }
}
