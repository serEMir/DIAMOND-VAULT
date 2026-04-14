// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";

/**
 * @title Diamond
 * @notice Minimal ERC-2535 diamond proxy that routes function selectors to registered facets.
 */
contract Diamond {
    /**
     * @notice Deploys the diamond and registers the initial `diamondCut` facet.
     * @param contractOwner The account that will control future upgrades.
     * @param diamondCutFacet The facet that exposes the `diamondCut` entrypoint.
     */
    constructor(address contractOwner, address diamondCutFacet) payable {
        LibDiamond.setContractOwner(contractOwner);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IDiamondCut.diamondCut.selector;
        LibDiamond.addFunctions(diamondCutFacet, selectors);
    }

    /**
     * @notice Delegates an unknown function call to the facet currently assigned to `msg.sig`.
     * @dev Reverts if no facet is registered for the selector.
     */
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");

        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @notice Accepts plain ETH transfers sent to the diamond.
     */
    receive() external payable {}
}
