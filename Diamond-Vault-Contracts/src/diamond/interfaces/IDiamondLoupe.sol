// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDiamondLoupe
 * @notice ERC-2535 interface for inspecting a diamond's currently registered facets and selectors.
 */
interface IDiamondLoupe {
    /**
     * @notice Groups a facet address with the selectors currently routed to it by the diamond.
     */
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Returns every active facet together with the selectors assigned to each one.
     * @return facets_ The full set of facet metadata registered in the diamond.
     */
    function facets() external view returns (Facet[] memory facets_);

    /**
     * @notice Returns all selectors currently routed to a specific facet.
     * @param facet The facet address to inspect.
     * @return facetFunctionSelectors_ The selectors assigned to `facet`.
     */
    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /**
     * @notice Returns the list of facet addresses currently registered in the diamond.
     * @return facetAddresses_ The active facet addresses.
     */
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /**
     * @notice Returns the facet that currently handles a selector.
     * @param functionSelector The selector to resolve.
     * @return facetAddress_ The facet address currently mapped to `functionSelector`.
     */
    function facetAddress(bytes4 functionSelector) external view returns (address facetAddress_);
}
