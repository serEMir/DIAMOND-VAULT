// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "../interfaces/IERC165.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @title DiamondLoupeFacet
 * @notice Facet that exposes read-only inspection helpers for the diamond's current routing table.
 */
contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    /**
     * @notice Returns every active facet and the selectors routed to it.
     * @return facets_ The registered facets and their selector sets.
     */
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 count = ds.facetAddresses.length;
        facets_ = new Facet[](count);

        for (uint256 i; i < count; i++) {
            address facetAddr = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddr;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddr].functionSelectors;
        }
    }

    /**
     * @notice Returns all selectors currently assigned to a facet.
     * @param facet The facet address to inspect.
     * @return selectors_ The selectors routed to `facet`.
     */
    function facetFunctionSelectors(address facet) external view override returns (bytes4[] memory selectors_) {
        selectors_ = LibDiamond.diamondStorage().facetFunctionSelectors[facet].functionSelectors;
    }

    /**
     * @notice Returns the list of currently active facet addresses.
     * @return facetAddresses_ The registered facet addresses.
     */
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        facetAddresses_ = LibDiamond.diamondStorage().facetAddresses;
    }

    /**
     * @notice Resolves a selector to the facet that currently handles it.
     * @param functionSelector The selector to resolve.
     * @return facetAddress_ The facet address currently mapped to the selector.
     */
    function facetAddress(bytes4 functionSelector) external view override returns (address facetAddress_) {
        facetAddress_ = LibDiamond.diamondStorage().selectorToFacetAndPosition[functionSelector].facetAddress;
    }

    /**
     * @notice Returns whether the diamond advertises support for an interface.
     * @param interfaceId The ERC-165 interface identifier to query.
     * @return True if the interface is marked as supported.
     */
    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return LibDiamond.diamondStorage().supportedInterfaces[interfaceId];
    }
}
