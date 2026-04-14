// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC173} from "../interfaces/IERC173.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @title OwnershipFacet
 * @notice Facet that exposes EIP-173 ownership controls for the diamond.
 */
contract OwnershipFacet is IERC173 {
    /**
     * @notice Returns the current diamond owner.
     * @return owner_ The owner stored in diamond storage.
     */
    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    /**
     * @notice Transfers diamond ownership to a new account.
     * @param newOwner The account that will become the new owner.
     */
    function transferOwnership(address newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(newOwner);
    }
}
