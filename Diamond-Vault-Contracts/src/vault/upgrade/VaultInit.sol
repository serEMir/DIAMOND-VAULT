// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";

/**
 * @title VaultInit
 * @notice Initialization contract used to configure the vault's asset and share metadata.
 */
contract VaultInit {
    /**
     * @notice Initializes the vault storage.
     * @param asset_ The underlying asset token managed by the vault.
     * @param name_ The ERC-20 name for the vault shares.
     * @param symbol_ The ERC-20 symbol for the vault shares.
     */
    function init(address asset_, string calldata name_, string calldata symbol_) external {
        LibVaultStorage.initialize(asset_, name_, symbol_);
    }
}
