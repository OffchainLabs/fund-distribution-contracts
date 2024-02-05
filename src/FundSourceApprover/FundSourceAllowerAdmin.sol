// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "./FundSourceAllower/Erc20FundSourceAllower.sol";
import "./FundSourceAllower/NativeFundSourceAllower.sol";

///@notice Creates FundSourceAllower contracts of which it is the admin of.
contract FundSourceAllowerAdmin is Ownable {
    // address to which funds in created NativeFundSourceAllowers get transfered
    address immutable nativeFundDestination;

    // address to which funds in created Erc20FundSourceAllower get transfered
    address immutable erc20FundDestination;

    error NotAContract(address addr);

    event NewFundSourceAlowerCreated(
        address addr,
        uint256 indexed chainId,
        address indexed token
    );
    event ApprovedToggled(bool approved, address allower);

    /// @param _owner initial address with affordances to create FundSourceAllowers and to toggle aprprovals
    /// @param _nativeFundDestination address to which funds in created NativeFundSourceAllowers get transfered
    /// @param _erc20FundDestination address to which funds in created Erc20FundSourceAllower get transfered

    constructor(address _owner, address _nativeFundDestination, address _erc20FundDestination) {
        _transferOwnership(_owner);
        nativeFundDestination = _nativeFundDestination;
        erc20FundDestination = _erc20FundDestination;
    }

    /// @notice create fund source allower that handles the native currency
    /// @param _sourceChainId chain ID of fund source, or other unique identifier (used for bookkeeping)
    function createNativeFundSourceAllower(
        uint256 _sourceChainId
    ) external onlyOwner {
        NativeFundSourceAllower allower = new NativeFundSourceAllower{
            salt: _getSalt(_sourceChainId, address(0))
        }(_sourceChainId, nativeFundDestination, address(this));
        emit NewFundSourceAlowerCreated({
            addr: address(allower),
            chainId: _sourceChainId,
            token: address(0)
        });
    }

    /// @notice create fund source allower that handles an ERC20
    /// @param _sourceChainId chain ID of fund source, or other unique identifier (used for bookkeeping)
    /// @param _token address on this chain of token that fund source allower will handle
    function createErc20FundSourceAllower(
        uint256 _sourceChainId,
        address _token
    ) external onlyOwner {
        if (!Address.isContract(_token)) {
            revert NotAContract(_token);
        }
        Erc20FundSourceAllower allower = new Erc20FundSourceAllower{
            salt: _getSalt(_sourceChainId, _token)
        }(_sourceChainId, erc20FundDestination, address(this), _token);
        emit NewFundSourceAlowerCreated({
            addr: address(allower),
            chainId: _sourceChainId,
            token: _token
        });
    }

    /// @notice Toggle approved for target allower; enables/ disables transfer of funds to destination
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
                abi.encode(_sourceChainId, nativeFundDestination, address(this))
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
                abi.encode(_sourceChainId, erc20FundDestination, address(this), _token)
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
