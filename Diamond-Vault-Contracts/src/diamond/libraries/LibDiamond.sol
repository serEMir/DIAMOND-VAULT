// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";

/**
 * @title LibDiamond
 * @notice Core library that owns the diamond's storage layout and selector-management logic.
 */
library LibDiamond {
    /*//////////////////////////////////////////////////////////////
                     ERRORS
    //////////////////////////////////////////////////////////////*/
    error LibDiamond__NotContractOwner(address caller, address owner);
    error LibDiamond__NoSelectorsProvidedForFacetForCut(address facetAddress);
    error LibDiamond__InvalidFacetCutAction(uint8 action);
    error LibDiamond__FacetAddressIsZero();
    error LibDiamond__FacetAddressIsNotZero();
    error LibDiamond__FacetHasNoCode(address facetAddress);
    error LibDiamond__FunctionAlreadyExists(bytes4 selector);
    error LibDiamond__FunctionDoesNotExist(bytes4 selector);
    error LibDiamond__CannotRemoveImmutableFunction(bytes4 selector);
    error LibDiamond__InitializationFunctionReverted(address init, bytes data);
    error LibDiamond__InitAddressHasNoCode(address init);
    error LibDiamond__InitCalldataMustBeEmpty();

    /*//////////////////////////////////////////////////////////////
                     TYPES
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Stores the facet responsible for a selector together with that selector's index.
     */
    struct FacetAddressAndSelectorPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    /**
     * @notice Tracks the selectors owned by a facet and the facet's position in the active facet list.
     */
    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position in facetAddresses array
    }

    /**
     * @notice Canonical storage layout used by the diamond core and all supporting facets.
     */
    struct DiamondStorage {
        // selector => facet address and selector position (within that facet's selector array)
        mapping(bytes4 => FacetAddressAndSelectorPosition) selectorToFacetAndPosition;
        // facet address => selectors and facet address position
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // list of facet addresses
        address[] facetAddresses;
        // ERC165 interface support
        mapping(bytes4 => bool) supportedInterfaces;
        // EIP-173 owner
        address contractOwner;
    }

    /*//////////////////////////////////////////////////////////////
                     STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Storage slot used to locate the diamond's shared state.
     */
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    /*//////////////////////////////////////////////////////////////
                     EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the diamond owner changes.
     * @param previousOwner The prior owner address.
     * @param newOwner The new owner address.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event DiamondCut(IDiamondCut.FacetCut[] diamondCut, address init, bytes initCalldata);

    /*//////////////////////////////////////////////////////////////
                     INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Updates the contract owner and emits the ownership transfer event.
     * @param newOwner The account that will become the new owner.
     */
    function setContractOwner(address newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    /**
     * @notice Registers new selectors for a facet.
     * @param facetAddress The facet that will receive the selectors.
     * @param selectors The selectors to register.
     */
    function addFunctions(address facetAddress, bytes4[] memory selectors) internal {
        if (facetAddress == address(0)) revert LibDiamond__FacetAddressIsZero();
        if (selectors.length == 0) revert LibDiamond__NoSelectorsProvidedForFacetForCut(facetAddress);
        _enforceHasCode(facetAddress);

        DiamondStorage storage ds = diamondStorage();
        FacetFunctionSelectors storage ffs = ds.facetFunctionSelectors[facetAddress];

        if (ffs.functionSelectors.length == 0) {
            _addFacet(ds, facetAddress);
        }

        for (uint256 i; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            if (ds.selectorToFacetAndPosition[selector].facetAddress != address(0)) {
                revert LibDiamond__FunctionAlreadyExists(selector);
            }
            _addFunction(ds, selector, facetAddress);
        }
    }

    /**
     * @notice Reassigns existing selectors from their current facets to a new facet.
     * @param facetAddress The facet that will handle the selectors after replacement.
     * @param selectors The selectors to move.
     */
    function replaceFunctions(address facetAddress, bytes4[] memory selectors) internal {
        if (facetAddress == address(0)) revert LibDiamond__FacetAddressIsZero();
        if (selectors.length == 0) revert LibDiamond__NoSelectorsProvidedForFacetForCut(facetAddress);
        _enforceHasCode(facetAddress);

        DiamondStorage storage ds = diamondStorage();
        FacetFunctionSelectors storage ffs = ds.facetFunctionSelectors[facetAddress];
        if (ffs.functionSelectors.length == 0) {
            _addFacet(ds, facetAddress);
        }

        for (uint256 i; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacet == address(0)) revert LibDiamond__FunctionDoesNotExist(selector);
            // If the function is defined directly on the Diamond (immutable), it has facetAddress == address(this).
            if (oldFacet == address(this)) revert LibDiamond__CannotRemoveImmutableFunction(selector);
            if (oldFacet == facetAddress) revert LibDiamond__FunctionAlreadyExists(selector);
            _removeFunction(ds, oldFacet, selector);
            _addFunction(ds, selector, facetAddress);
        }
    }

    /**
     * @notice Removes selectors from the diamond's routing table.
     * @param facetAddress Must be `address(0)` for remove cuts.
     * @param selectors The selectors to remove.
     */
    function removeFunctions(address facetAddress, bytes4[] memory selectors) internal {
        if (facetAddress != address(0)) revert LibDiamond__FacetAddressIsNotZero();
        if (selectors.length == 0) revert LibDiamond__NoSelectorsProvidedForFacetForCut(facetAddress);

        DiamondStorage storage ds = diamondStorage();
        for (uint256 i; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            address oldFacet = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacet == address(0)) revert LibDiamond__FunctionDoesNotExist(selector);
            // If the function is defined directly on the Diamond (immutable), it has facetAddress == address(this).
            if (oldFacet == address(this)) revert LibDiamond__CannotRemoveImmutableFunction(selector);
            _removeFunction(ds, oldFacet, selector);
        }
    }

    /**
     * @notice Applies a full diamond cut and optionally runs initialization logic afterward.
     * @param cut The ordered list of facet operations to execute.
     * @param init The contract or facet to delegatecall after the cut.
     * @param initCalldata The calldata supplied to `init`.
     */
    function diamondCut(IDiamondCut.FacetCut[] memory cut, address init, bytes memory initCalldata) internal {
        for (uint256 i; i < cut.length; i++) {
            IDiamondCut.FacetCutAction action = cut[i].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(cut[i].facetAddress, cut[i].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(cut[i].facetAddress, cut[i].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(cut[i].facetAddress, cut[i].functionSelectors);
            } else {
                revert LibDiamond__InvalidFacetCutAction(uint8(action));
            }
        }

        emit DiamondCut(cut, init, initCalldata);
        _initializeDiamondCut(init, initCalldata);
    }

    /*//////////////////////////////////////////////////////////////
                     PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Executes the optional post-cut initialization delegatecall.
     * @param init The contract or facet to delegatecall.
     * @param initCalldata The calldata supplied to `init`.
     */
    function _initializeDiamondCut(address init, bytes memory initCalldata) private {
        if (init == address(0)) {
            if (initCalldata.length != 0) revert LibDiamond__InitCalldataMustBeEmpty();
            return;
        }
        _enforceHasCode(init, true);

        (bool success, bytes memory error) = init.delegatecall(initCalldata);
        if (!success) revert LibDiamond__InitializationFunctionReverted(init, error);
    }

    /**
     * @notice Adds a facet address to the list of active facets.
     * @param ds The diamond storage pointer.
     * @param facetAddress The facet address to register.
     */
    function _addFacet(DiamondStorage storage ds, address facetAddress) private {
        ds.facetFunctionSelectors[facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(facetAddress);
    }

    /**
     * @notice Assigns a selector to a facet and records its position in that facet's selector array.
     * @param ds The diamond storage pointer.
     * @param selector The selector to register.
     * @param facetAddress The facet that will own the selector.
     */
    function _addFunction(DiamondStorage storage ds, bytes4 selector, address facetAddress) private {
        FacetFunctionSelectors storage ffs = ds.facetFunctionSelectors[facetAddress];
        ds.selectorToFacetAndPosition[selector] = FacetAddressAndSelectorPosition({
            facetAddress: facetAddress, functionSelectorPosition: uint96(ffs.functionSelectors.length)
        });
        ffs.functionSelectors.push(selector);
    }

    /**
     * @notice Removes a selector from a facet and keeps the facet's selector array packed.
     * @param ds The diamond storage pointer.
     * @param facetAddress The facet currently assigned to the selector.
     * @param selector The selector to remove.
     */
    function _removeFunction(DiamondStorage storage ds, address facetAddress, bytes4 selector) private {
        // selectorToFacetAndPosition will be cleared at the end.
        FacetAddressAndSelectorPosition memory old = ds.selectorToFacetAndPosition[selector];
        if (old.facetAddress != facetAddress) revert LibDiamond__FunctionDoesNotExist(selector);

        FacetFunctionSelectors storage ffs = ds.facetFunctionSelectors[facetAddress];
        uint256 selectorPos = old.functionSelectorPosition;
        uint256 lastSelectorPos = ffs.functionSelectors.length - 1;

        if (selectorPos != lastSelectorPos) {
            bytes4 lastSelector = ffs.functionSelectors[lastSelectorPos];
            ffs.functionSelectors[selectorPos] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPos);
        }
        ffs.functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[selector];

        if (ffs.functionSelectors.length == 0) {
            _removeFacet(ds, facetAddress);
        }
    }

    /**
     * @notice Removes a facet from the active facet list once it no longer owns any selectors.
     * @param ds The diamond storage pointer.
     * @param facetAddress The facet to unregister.
     */
    function _removeFacet(DiamondStorage storage ds, address facetAddress) private {
        uint256 facetPos = ds.facetFunctionSelectors[facetAddress].facetAddressPosition;
        uint256 lastFacetPos = ds.facetAddresses.length - 1;

        if (facetPos != lastFacetPos) {
            address lastFacet = ds.facetAddresses[lastFacetPos];
            ds.facetAddresses[facetPos] = lastFacet;
            ds.facetFunctionSelectors[lastFacet].facetAddressPosition = facetPos;
        }
        ds.facetAddresses.pop();
        delete ds.facetFunctionSelectors[facetAddress].facetAddressPosition;
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns the storage pointer for the diamond's shared state.
     * @return ds The storage struct located at `DIAMOND_STORAGE_POSITION`.
     */
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Returns the current owner recorded in diamond storage.
     * @return owner_ The owner address.
     */
    function contractOwner() internal view returns (address owner_) {
        owner_ = diamondStorage().contractOwner;
    }

    /**
     * @notice Reverts unless the caller is the current diamond owner.
     */
    function enforceIsContractOwner() internal view {
        DiamondStorage storage ds = diamondStorage();
        if (msg.sender != ds.contractOwner) {
            revert LibDiamond__NotContractOwner(msg.sender, ds.contractOwner);
        }
    }

    /*//////////////////////////////////////////////////////////////
                     PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verifies that a facet address contains deployed runtime code.
     * @param facetAddress The facet address to validate.
     */
    function _enforceHasCode(address facetAddress) private view {
        _enforceHasCode(facetAddress, false);
    }

    /**
     * @notice Verifies that an address contains deployed runtime code.
     * @param addr The address to validate.
     * @param isInit True when validating the post-cut init target, false when validating a facet.
     */
    function _enforceHasCode(address addr, bool isInit) private view {
        if (addr.code.length == 0) {
            if (isInit) revert LibDiamond__InitAddressHasNoCode(addr);
            revert LibDiamond__FacetHasNoCode(addr);
        }
    }
}
