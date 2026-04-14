// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDiamondCut
 * @notice ERC-2535 interface for managing diamond upgrades.
 */
interface IDiamondCut {
    /**
     * @notice Supported operations that can be applied to a selector set during a cut.
     */
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /**
     * @notice Describes a single facet modification to apply during `diamondCut`.
     * @dev For remove operations, `facetAddress` must be `address(0)`.
     */
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Emitted after a diamond cut is applied.
     * @param diamondCut The list of facet modifications that were executed.
     * @param init The contract or facet delegatecalled for post-upgrade initialization.
     * @param initCalldata The calldata supplied to `init`.
     */
    event DiamondCut(FacetCut[] diamondCut, address init, bytes initCalldata);

    /**
     * @notice Adds, replaces, or removes selectors and optionally runs initialization logic.
     * @param diamondCut The set of facet operations to execute.
     * @param init The contract or facet to delegatecall after applying the cut.
     * @param initCalldata The calldata to pass to `init`.
     */
    function diamondCut(FacetCut[] calldata diamondCut, address init, bytes calldata initCalldata) external;
}
