// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @title DiamondCutFacet
 * @notice Facet that exposes the `diamondCut` upgrade entrypoint.
 */
contract DiamondCutFacet is IDiamondCut {
    /**
     * @notice Applies a diamond cut and optionally runs initialization logic.
     * @param cut The list of selector operations to execute.
     * @param init The contract or facet to delegatecall after the cut.
     * @param initCalldata The calldata supplied to `init`.
     */
    function diamondCut(FacetCut[] calldata cut, address init, bytes calldata initCalldata) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_toMemory(cut), init, initCalldata);
    }

    /**
     * @notice Copies the calldata facet cut array into memory.
     * @dev `LibDiamond` expects a memory array because it emits the cut and performs initialization.
     * @param cut The facet cut operations supplied to the external entrypoint.
     * @return mem The same operations copied into memory.
     */
    function _toMemory(FacetCut[] calldata cut) private pure returns (FacetCut[] memory mem) {
        mem = new FacetCut[](cut.length);
        for (uint256 i; i < cut.length; i++) {
            mem[i] = cut[i];
        }
    }
}
