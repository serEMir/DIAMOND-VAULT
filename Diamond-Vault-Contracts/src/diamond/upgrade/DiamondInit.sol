// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "../interfaces/IERC165.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @title DiamondInit
 * @notice Initialization contract used during upgrades to register supported interfaces.
 * @dev This contract is meant to be executed via `delegatecall` from `diamondCut`.
 */
contract DiamondInit {
    /**
     * @notice Registers the core ERC-165 interface identifiers supported by the diamond.
     * @dev Writes directly into diamond storage because this function is intended to run via `delegatecall`.
     */
    function init() external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }
}
