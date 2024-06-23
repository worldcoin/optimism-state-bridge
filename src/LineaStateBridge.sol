// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {IMessageService} from  "./interfaces/IMessageService.sol";
import {ILineaWorldID} from "./interfaces/ILineaWorldID.sol";
import {IRootHistory} from "./interfaces/IRootHistory.sol";
import {IWorldIDIdentityManager} from "./interfaces/IWorldIDIdentityManager.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {ICrossDomainOwnable3} from "./interfaces/ICrossDomainOwnable3.sol";

/// @title World ID State Bridge Linea
/// @author Worldcoin & James Harrison
/// @notice Distributes new World ID Identity Manager roots to an Linea Stack network
/// @dev This contract lives on Ethereum mainnet and works for Linea.
contract LineaStateBridge is Ownable2Step {
    ///////////////////////////////////////////////////////////////////
    ///                           STORAGE                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice The address of the LinearWorldID contract on any Linea Stack chain
    address public immutable lineaWorldIDAddress;

    /// @notice address for Linea Stack chain Ethereum mainnet L1CrossDomainMessenger contract
    address internal immutable crossDomainMessengerAddress;

    /// @notice Ethereum mainnet worldID Address
    address public immutable worldIDAddress;

    /// @notice Amount of gas purchased on the Linea Stack chain for propagateRoot
    uint32 internal _gasLimitPropagateRoot;

    /// @notice Amount of gas purchased on the OLinea Stack chain for SetRootHistoryExpiry
    uint32 internal _gasLimitSetRootHistoryExpiry;

    /// @notice Amount of gas purchased on the Linea Stack chain for transferOwnershipOp
    uint32 internal _gasLimitTransferOwnership;

    /// @notice The default gas limit amount to buy on an Linea stack chain to do simple transactions
    uint32 public constant DEFAULT_LINEA_GAS_LIMIT = 1000000;

    ///////////////////////////////////////////////////////////////////
    ///                            EVENTS                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Emitted when the StateBridge gives ownership of the LineaWorldID contract
    /// to the WorldID Identity Manager contract away
    /// @param previousOwner The previous owner of the LineaWorldID contract
    /// @param newOwner The new owner of the LineaWorldID contract
    /// @param isLocal Whether the ownership transfer is local (Linea/Linea Stack chain EOA/contract)
    /// or an Ethereum EOA or contract
    event OwnershipTransferredLinea(
        address indexed previousOwner, address indexed newOwner, bool isLocal
    );

    /// @notice Emitted when the StateBridge sends a root to the LineaWorldID contract
    /// @param root The root sent to the LineaWorldID contract on the Linea Stack chain
    event RootPropagated(uint256 root);

    /// @notice Emitted when the StateBridge sets the root history expiry for OpWorldID, LineaWorldID and PolygonWorldID
    /// @param rootHistoryExpiry The new root history expiry
    event SetRootHistoryExpiry(uint256 rootHistoryExpiry);

    /// @notice Emitted when the StateBridge sets the gas limit for sendRootOp
    /// @param _lineaGasLimit The new opGasLimit for sendRootOp
    event SetGasLimitPropagateRoot(uint32 _lineaGasLimit);

    /// @notice Emitted when the StateBridge sets the gas limit for SetRootHistoryExpiry
    /// @param _lineaGasLimit The new opGasLimit for SetRootHistoryExpiry
    event SetGasLimitSetRootHistoryExpiry(uint32 _lineaGasLimit);

    /// @notice Emitted when the StateBridge sets the gas limit for transferOwnershipOp
    /// @param _lineaGasLimit The new opGasLimit for transferOwnershipOptimism
    event SetGasLimitTransferOwnershipLinea(uint32 _lineaGasLimit);

    ///////////////////////////////////////////////////////////////////
    ///                            ERRORS                           ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Emitted when an attempt is made to renounce ownership.
    error CannotRenounceOwnership();

    /// @notice Emitted when an attempt is made to set the gas limit to zero
    error GasLimitZero();

    /// @notice Emitted when an attempt is made to set an address to zero
    error AddressZero();

    ///////////////////////////////////////////////////////////////////
    ///                         CONSTRUCTOR                         ///
    ///////////////////////////////////////////////////////////////////

    /// @notice constructor
    /// @param _worldIDIdentityManager Deployment address of the WorldID Identity Manager contract
    /// @param _lineaWorldIDAddress Address of the Optimism contract that will receive the new root and timestamp
    /// @param _crossDomainMessenger L1CrossDomainMessenger contract used to communicate with the desired OP
    /// Stack network
    /// @custom:revert if any of the constructor params addresses are zero
    constructor(
        address _worldIDIdentityManager,
        address _lineaWorldIDAddress,
        address _crossDomainMessenger
    ) {
        if (
            _worldIDIdentityManager == address(0) || _lineaWorldIDAddress == address(0)
                || _crossDomainMessenger == address(0)
        ) {
            revert AddressZero();
        }

        lineaWorldIDAddress = _lineaWorldIDAddress;
        worldIDAddress = _worldIDIdentityManager;
        crossDomainMessengerAddress = _crossDomainMessenger;
        _gasLimitPropagateRoot = DEFAULT_LINEA_GAS_LIMIT;
        _gasLimitSetRootHistoryExpiry = DEFAULT_LINEA_GAS_LIMIT;
        _gasLimitTransferOwnership = DEFAULT_LINEA_GAS_LIMIT;
    }

    ///////////////////////////////////////////////////////////////////
    ///                          PUBLIC API                         ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Sends the latest WorldID Identity Manager root to the ILineaStack.
    /// @dev Calls this method on the L1 Proxy contract to relay roots to the destination Linea Stack chain
    function propagateRoot() external {
        uint256 latestRoot = IWorldIDIdentityManager(worldIDAddress).latestRoot();

        // The `encodeCall` function is strongly typed, so this checks that we are passing the
        // correct data to the optimism bridge.
        bytes memory message = abi.encodeCall(ILineaWorldID.receiveRoot, (latestRoot));

        IMessageService(crossDomainMessengerAddress).sendMessage(
            // Contract address on the OP Stack Chain
            lineaWorldIDAddress, _gasLimitPropagateRoot, message );

        emit RootPropagated(latestRoot);
    }

    /// @notice Adds functionality to the StateBridge to transfer ownership
    /// of LineaWorldID to another contract on L1 or to a local Linea Stack chain EOA
    /// @param _owner new owner (EOA or contract)
    /// @param _isLocal true if new owner is on Linea, false if it is a cross-domain owner
    /// @custom:revert if _owner is set to the zero address
    function transferOwnershipLineas(address _owner, bool _isLocal) external onlyOwner {
        if (_owner == address(0)) {
            revert AddressZero();
        }

        // The `encodeCall` function is strongly typed, so this checks that we are passing the
        // correct data to the OP Stack chain bridge.
        bytes memory message =
            abi.encodeCall(ICrossDomainOwnable3.transferOwnership, (_owner, _isLocal));

        IMessageService(crossDomainMessengerAddress).sendMessage(
            // Contract address on the Linea Stack Chain
            lineaWorldIDAddress,
            _gasLimitTransferOwnership,
            message
        );

        emit OwnershipTransferredLinea(owner(), _owner, _isLocal);
    }

    /// @notice Adds functionality to the StateBridge to set the root history expiry on LineaWorldID
    /// @param _rootHistoryExpiry new root history expiry
    function setRootHistoryExpiry(uint256 _rootHistoryExpiry) external onlyOwner {
        // The `encodeCall` function is strongly typed, so this checks that we are passing the
        // correct data to the optimism bridge.
        bytes memory message =
            abi.encodeCall(IRootHistory.setRootHistoryExpiry, (_rootHistoryExpiry));

        IMessageService(crossDomainMessengerAddress).sendMessage(
            // Contract address on the OP Stack Chain
            lineaWorldIDAddress,
            _gasLimitSetRootHistoryExpiry,
            message
        );

        emit SetRootHistoryExpiry(_rootHistoryExpiry);
    }

    ///////////////////////////////////////////////////////////////////
    ///                         Linea GAS LIMIT                        ///
    ///////////////////////////////////////////////////////////////////

    /// @notice Sets the gas limit for the propagateRoot method
    /// @param _lineaGasLimit The new gas limit for the propagateRoot method
    function setGasLimitPropagateRoot(uint32 _lineaGasLimit) external onlyOwner {
        if (_lineaGasLimit <= 0) {
            revert GasLimitZero();
        }

        _gasLimitPropagateRoot = _lineaGasLimit;

        emit SetGasLimitPropagateRoot(_lineaGasLimit);
    }

    /// @notice Sets the gas limit for the SetRootHistoryExpiry method
    /// @param _lineaGasLimit The new gas limit for the SetRootHistoryExpiry method
    function setGasLimitSetRootHistoryExpiry(uint32 _lineaGasLimit) external onlyOwner {
        if (_lineaGasLimit <= 0) {
            revert GasLimitZero();
        }

        _gasLimitSetRootHistoryExpiry = _lineaGasLimit;

        emit SetGasLimitSetRootHistoryExpiry(_lineaGasLimit);
    }

    /// @notice Sets the gas limit for the transferOwnershipOp method
    /// @param _lineaGasLimit The new gas limit for the transferOwnershipOp method
    function setGasLimitTransferOwnershipOp(uint32 _lineaGasLimit) external onlyOwner {
        if (_lineaGasLimit <= 0) {
            revert GasLimitZero();
        }

        _gasLimitTransferOwnership = _lineaGasLimit;

        emit SetGasLimitTransferOwnershipLinea(_lineaGasLimit);
    }

    ///////////////////////////////////////////////////////////////////
    ///                          OWNERSHIP                          ///
    ///////////////////////////////////////////////////////////////////
    /// @notice Ensures that ownership of WorldID implementations cannot be renounced.
    /// @dev This function is intentionally not `virtual` as we do not want it to be possible to
    ///      renounce ownership for any WorldID implementation.
    /// @dev This function is marked as `onlyOwner` to maintain the access restriction from the base
    ///      contract.
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
    }
}

