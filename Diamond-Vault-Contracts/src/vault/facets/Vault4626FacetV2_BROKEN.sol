// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibVaultControl} from "../libraries/LibVaultControl.sol";
import {LibReentrancyGuard} from "../libraries/LibReentrancyGuard.sol";
import {LibVaultStorage_BROKEN} from "../libraries/LibVaultStorage_BROKEN.sol";

/**
 * @title Vault4626FacetV2_BROKEN
 * @notice INTENTIONALLY BROKEN VERSION with mid-struct insertion to demonstrate storage collision.
 *
 * This facet has a CRITICAL BUG: a new field is inserted in the MIDDLE of VaultStorage,
 * causing the mapping slots to shift. This breaks all user balances.
 *
 * DO NOT USE IN PRODUCTION. This is for testing only.
 */
contract Vault4626FacetV2_BROKEN {
    using SafeERC20 for IERC20;

    /**
     * @notice BROKEN STORAGE LAYOUT: Field inserted in the middle!
     *
     * Original VaultStorage had:
     *   slot 0-4: asset, assetDecimals, reserved, name, symbol, totalSupply, initialized
     *   slot 5: mapping balances
     *   slot 6: mapping allowances
     *
     * This broken version inserts a new field, shifting everything:
     *   slot 0-4: asset, assetDecimals, reserved, name, symbol, totalSupply, initialized
     *   slot 5: newTrackedDeposits (NEW FIELD - INSERTED IN MIDDLE!)
     *   slot 6: mapping balances (SHIFTED FROM 5!)
     *   slot 7: mapping allowances (SHIFTED FROM 6!)
     *
     * Result: balanceOf(alice) reads from keccak256(alice, 6) instead of keccak256(alice, 5).
     * Alice's balance sits untouched at the old location. The new code finds zeros.
     */

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /**
     * @notice Returns the underlying asset managed by the vault.
     * @return assetTokenAddress The asset token address.
     */
    function asset() external view returns (address assetTokenAddress) {
        assetTokenAddress = LibVaultStorage_BROKEN.vaultStorage().asset;
    }

    /**
     * @notice Returns the amount of underlying assets currently held by the vault.
     * @return totalManagedAssets The current vault asset balance.
     */
    function totalAssets() public view returns (uint256 totalManagedAssets) {
        totalManagedAssets = LibVaultStorage_BROKEN.totalAssets();
    }

    /**
     * @notice Converts an asset amount to shares using the current exchange rate.
     * @param assets The amount of assets to convert.
     * @return shares The corresponding amount of shares.
     */
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        shares = LibVaultStorage_BROKEN.convertToShares(assets, false);
    }

    /**
     * @notice Converts a share amount to assets using the current exchange rate.
     * @param shares The amount of shares to convert.
     * @return assets The corresponding amount of assets.
     */
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = LibVaultStorage_BROKEN.convertToAssets(shares, false);
    }

    /**
     * @notice Returns the maximum assets a receiver can deposit.
     * @param receiver The receiver address, ignored by this implementation.
     * @return maxAssets The current deposit limit in assets.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets) {
        receiver;
        maxAssets =
            (!LibVaultControl.depositsPaused() && LibVaultStorage_BROKEN.isDepositAllowed()) ? type(uint256).max : 0;
    }

    /**
     * @notice Returns the shares that would be minted for a deposit.
     * @param assets The assets to simulate depositing.
     * @return shares The shares that would be minted.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        shares = LibVaultStorage_BROKEN.convertToShares(assets, false);
    }

    /**
     * @notice Deposits assets and mints the corresponding shares to a receiver.
     * @param assets The amount of assets to deposit.
     * @param receiver The account that will receive the minted shares.
     * @return shares The amount of shares minted.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        LibReentrancyGuard.enter();
        LibVaultControl.revertIfDepositsPaused();
        if (assets == 0) revert LibVaultStorage_BROKEN.LibVaultStorage__ZeroAssets();

        LibVaultStorage_BROKEN.VaultStorage storage vs = LibVaultStorage_BROKEN.vaultStorage();
        uint256 supplyBefore = vs.totalSupply;
        uint256 assetsBefore = totalAssets();

        IERC20(vs.asset).safeTransferFrom(msg.sender, address(this), assets);

        uint256 received = totalAssets() - assetsBefore;
        if (received != assets) {
            revert LibVaultStorage_BROKEN.LibVaultStorage__AssetTransferMismatch(assets, received);
        }

        shares = LibVaultStorage_BROKEN.convertToSharesAtSnapshot(assets, supplyBefore, assetsBefore, false);
        LibVaultStorage_BROKEN.mintShares(receiver, shares);

        LibReentrancyGuard.exit();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Returns the maximum shares a receiver can mint.
     * @param receiver The receiver address, ignored by this implementation.
     * @return maxShares The current mint limit in shares.
     */
    function maxMint(address receiver) external view returns (uint256 maxShares) {
        receiver;
        maxShares =
            (!LibVaultControl.depositsPaused() && LibVaultStorage_BROKEN.isDepositAllowed()) ? type(uint256).max : 0;
    }

    /**
     * @notice Returns the assets required to mint a given amount of shares.
     * @param shares The shares to simulate minting.
     * @return assets The assets that would be required.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        assets = LibVaultStorage_BROKEN.convertToAssets(shares, true);
    }

    /**
     * @notice Mints shares by transferring the required amount of assets into the vault.
     * @param shares The amount of shares to mint.
     * @param receiver The account that will receive the minted shares.
     * @return assets The amount of assets pulled from the caller.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        LibReentrancyGuard.enter();
        LibVaultControl.revertIfDepositsPaused();
        if (shares == 0) revert LibVaultStorage_BROKEN.LibVaultStorage__ZeroShares();

        LibVaultStorage_BROKEN.VaultStorage storage vs = LibVaultStorage_BROKEN.vaultStorage();
        uint256 assetsBefore = totalAssets();

        assets = LibVaultStorage_BROKEN.convertToAssets(shares, true);
        IERC20(vs.asset).safeTransferFrom(msg.sender, address(this), assets);

        uint256 received = totalAssets() - assetsBefore;
        if (received < assets) {
            revert LibVaultStorage_BROKEN.LibVaultStorage__AssetTransferMismatch(assets, received);
        }

        LibVaultStorage_BROKEN.mintShares(receiver, shares);

        LibReentrancyGuard.exit();
        emit Deposit(msg.sender, receiver, received, shares);
    }

    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        if (LibVaultControl.withdrawalsPaused()) {
            return 0;
        }
        uint256 ownerShares = LibVaultStorage_BROKEN.vaultStorage().balances[owner];
        maxAssets = LibVaultStorage_BROKEN.convertToAssets(ownerShares, false);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        shares = LibVaultStorage_BROKEN.convertToShares(assets, true);
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        shares = LibVaultStorage_BROKEN.convertToShares(assets, true);
        _withdraw(assets, receiver, owner, shares);
    }

    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        if (LibVaultControl.withdrawalsPaused()) {
            return 0;
        }
        maxShares = LibVaultStorage_BROKEN.vaultStorage().balances[owner];
    }

    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        assets = LibVaultStorage_BROKEN.convertToAssets(shares, false);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        assets = LibVaultStorage_BROKEN.convertToAssets(shares, false);
        _withdraw(assets, receiver, owner, shares);
    }

    function _withdraw(uint256 assets, address receiver, address owner, uint256 shares) internal {
        LibReentrancyGuard.enter();
        LibVaultControl.revertIfWithdrawalsPaused();

        if (msg.sender != owner) {
            LibVaultStorage_BROKEN.VaultStorage storage vs = LibVaultStorage_BROKEN.vaultStorage();
            uint256 allowed = vs.allowances[owner][msg.sender];
            if (allowed < shares) {
                revert LibVaultStorage_BROKEN.LibVaultStorage__InsufficientAllowance(owner, msg.sender, allowed, shares);
            }
            vs.allowances[owner][msg.sender] = allowed - shares;
        }

        LibVaultStorage_BROKEN.burnShares(owner, shares);

        IERC20(LibVaultStorage_BROKEN.vaultStorage().asset).safeTransfer(receiver, assets);

        LibReentrancyGuard.exit();
    }
}
