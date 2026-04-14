// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LibVaultControl} from "../libraries/LibVaultControl.sol";
import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";

/**
 * @title VaultShareFacet
 * @notice ERC-20 style share accounting facet for the vault.
 */
contract VaultShareFacet is IERC20Metadata {
    /**
     * @notice Returns the vault share token name.
     * @return The ERC-20 name string.
     */
    function name() external view override returns (string memory) {
        return LibVaultStorage.vaultStorage().name;
    }

    /**
     * @notice Returns the vault share token symbol.
     * @return The ERC-20 symbol string.
     */
    function symbol() external view override returns (string memory) {
        return LibVaultStorage.vaultStorage().symbol;
    }

    /**
     * @notice Returns the decimals used by the vault shares.
     * @return The decimals value exposed by the share token.
     */
    function decimals() external pure override returns (uint8) {
        return LibVaultStorage.shareDecimals();
    }

    /**
     * @notice Returns the total supply of vault shares.
     * @return The total minted share supply.
     */
    function totalSupply() external view override returns (uint256) {
        return LibVaultStorage.vaultStorage().totalSupply;
    }

    /**
     * @notice Returns the share balance of an account.
     * @param account The account to query.
     * @return The account's share balance.
     */
    function balanceOf(address account) external view override returns (uint256) {
        return LibVaultStorage.vaultStorage().balances[account];
    }

    /**
     * @notice Returns the remaining share allowance from `owner` to `spender`.
     * @param owner The share owner who granted the allowance.
     * @param spender The account allowed to spend the shares.
     * @return The remaining allowance amount.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return LibVaultStorage.vaultStorage().allowances[owner][spender];
    }

    /**
     * @notice Sets a share allowance for a spender.
     * @param spender The account allowed to spend the caller's shares.
     * @param value The allowance amount to set.
     * @return True after the allowance is stored.
     */
    function approve(address spender, uint256 value) external override returns (bool) {
        LibVaultStorage.approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice Transfers vault shares to another account.
     * @param to The recipient of the shares.
     * @param value The amount of shares to transfer.
     * @return True after the transfer succeeds.
     */
    function transfer(address to, uint256 value) external override returns (bool) {
        LibVaultControl.revertIfShareTransfersPaused();
        LibVaultStorage.transferShares(msg.sender, to, value);
        return true;
    }

    /**
     * @notice Transfers vault shares using an existing allowance.
     * @param from The account to transfer shares from.
     * @param to The recipient of the shares.
     * @param value The amount of shares to transfer.
     * @return True after the transfer succeeds.
     */
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        LibVaultControl.revertIfShareTransfersPaused();
        if (from != msg.sender) {
            LibVaultStorage.spendAllowance(from, msg.sender, value);
        }
        LibVaultStorage.transferShares(from, to, value);
        return true;
    }
}
