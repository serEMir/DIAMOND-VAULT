// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LibVaultStorage_BROKEN} from "../libraries/LibVaultStorage_BROKEN.sol";

/**
 * @title VaultShareFacetV2_BROKEN
 * @notice INTENTIONALLY BROKEN ERC-20 facet that uses the broken storage library.
 *
 * This facet is deployed alongside Vault4626FacetV2_BROKEN to demonstrate that
 * when you insert a field in the middle of a struct, ALL facets that access that
 * struct must be updated with the new layout - otherwise they read from wrong slots.
 */
contract VaultShareFacetV2_BROKEN is IERC20Metadata {
    /**
     * @notice Returns the vault share token name.
     * @return The ERC-20 name string.
     */
    function name() external view override returns (string memory) {
        return LibVaultStorage_BROKEN.vaultStorage().name;
    }

    /**
     * @notice Returns the vault share token symbol.
     * @return The ERC-20 symbol string.
     */
    function symbol() external view override returns (string memory) {
        return LibVaultStorage_BROKEN.vaultStorage().symbol;
    }

    /**
     * @notice Returns the decimals used by the vault shares.
     * @return The decimals value exposed by the share token.
     */
    function decimals() external pure override returns (uint8) {
        return LibVaultStorage_BROKEN.shareDecimals();
    }

    /**
     * @notice Returns the total supply of vault shares.
     * @return The total minted share supply.
     */
    function totalSupply() external view override returns (uint256) {
        return LibVaultStorage_BROKEN.vaultStorage().totalSupply;
    }

    /**
     * @notice Returns the share balance of an account.
     * @param account The account to query.
     * @return The account's share balance.
     *
     * BROKEN: This reads from the SHIFTED mapping location due to mid-struct insertion!
     */
    function balanceOf(address account) external view override returns (uint256) {
        return LibVaultStorage_BROKEN.vaultStorage().balances[account];
    }

    /**
     * @notice Returns the remaining share allowance from `owner` to `spender`.
     * @param owner The share owner who granted the allowance.
     * @param spender The account allowed to spend the shares.
     * @return The remaining allowance amount.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return LibVaultStorage_BROKEN.vaultStorage().allowances[owner][spender];
    }

    /**
     * @notice Approves shares from the caller to a spender.
     * @param spender The account to approve.
     * @param amount The amount of shares to approve.
     * @return Always true.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        LibVaultStorage_BROKEN.approve(msg.sender, spender, amount);
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfers shares from the caller to a recipient.
     * @param to The recipient address.
     * @param amount The amount of shares to transfer.
     * @return Always true.
     */
    function transfer(address to, uint256 amount) external override returns (bool) {
        LibVaultStorage_BROKEN.revertIfCannotSpendShares(msg.sender, msg.sender, amount);
        LibVaultStorage_BROKEN.transferShares(msg.sender, to, amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Transfers shares from one account to another (requires allowance).
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount of shares to transfer.
     * @return Always true.
     */
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        LibVaultStorage_BROKEN.revertIfCannotSpendShares(from, msg.sender, amount);
        LibVaultStorage_BROKEN.transferShares(from, to, amount);
        if (msg.sender != from) {
            LibVaultStorage_BROKEN.spendAllowance(from, msg.sender, amount);
        }
        emit Transfer(from, to, amount);
        return true;
    }
}
