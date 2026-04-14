// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibStrategyStorage} from "../../strategy/libraries/LibStrategyStorage.sol";
import {LibVaultControl} from "../libraries/LibVaultControl.sol";
import {LibReentrancyGuard} from "../libraries/LibReentrancyGuard.sol";
import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";

/**
 * @title Vault4626Facet
 * @notice ERC-4626 style deposit, mint, withdraw, and redeem facet for the vault.
 */
contract Vault4626Facet {
    using SafeERC20 for IERC20;

    /**
     * @notice Emitted when assets are deposited and shares are minted.
     * @param sender The account that supplied the assets.
     * @param owner The account that received the shares.
     * @param assets The amount of assets deposited.
     * @param shares The amount of shares minted.
     */
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when shares are burned and assets are withdrawn.
     * @param sender The account that initiated the withdrawal.
     * @param receiver The account that received the assets.
     * @param owner The account whose shares were burned.
     * @param assets The amount of assets withdrawn.
     * @param shares The amount of shares burned.
     */
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /**
     * @notice Returns the underlying asset managed by the vault.
     * @return assetTokenAddress The asset token address.
     */
    function asset() external view returns (address assetTokenAddress) {
        assetTokenAddress = LibVaultStorage.vaultStorage().asset;
    }

    /**
     * @notice Returns the amount of underlying assets currently held by the vault.
     * @return totalManagedAssets The current vault asset balance.
     */
    function totalAssets() public view returns (uint256 totalManagedAssets) {
        totalManagedAssets = LibVaultStorage.totalAssets();
    }

    /**
     * @notice Converts an asset amount to shares using the current exchange rate.
     * @param assets The amount of assets to convert.
     * @return shares The corresponding amount of shares.
     */
    function convertToShares(uint256 assets) public view returns (uint256 shares) {
        shares = LibVaultStorage.convertToShares(assets, false);
    }

    /**
     * @notice Converts a share amount to assets using the current exchange rate.
     * @param shares The amount of shares to convert.
     * @return assets The corresponding amount of assets.
     */
    function convertToAssets(uint256 shares) public view returns (uint256 assets) {
        assets = LibVaultStorage.convertToAssets(shares, false);
    }

    /**
     * @notice Returns the maximum assets a receiver can deposit.
     * @param receiver The receiver address, ignored by this implementation.
     * @return maxAssets The current deposit limit in assets.
     */
    function maxDeposit(address receiver) external view returns (uint256 maxAssets) {
        receiver;
        maxAssets = (!LibVaultControl.depositsPaused() && LibVaultStorage.isDepositAllowed()) ? type(uint256).max : 0;
    }

    /**
     * @notice Returns the shares that would be minted for a deposit.
     * @param assets The assets to simulate depositing.
     * @return shares The shares that would be minted.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares) {
        shares = LibVaultStorage.convertToShares(assets, false);
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
        if (assets == 0) revert LibVaultStorage.LibVaultStorage__ZeroAssets();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 supplyBefore = vs.totalSupply;
        uint256 assetsBefore = totalAssets();

        IERC20(vs.asset).safeTransferFrom(msg.sender, address(this), assets);

        uint256 received = totalAssets() - assetsBefore;
        if (received != assets) {
            revert LibVaultStorage.LibVaultStorage__AssetTransferMismatch(assets, received);
        }

        shares = LibVaultStorage.convertToSharesAtSnapshot(assets, supplyBefore, assetsBefore, false);
        LibVaultStorage.mintShares(receiver, shares);

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
        maxShares = (!LibVaultControl.depositsPaused() && LibVaultStorage.isDepositAllowed()) ? type(uint256).max : 0;
    }

    /**
     * @notice Returns the assets required to mint a given amount of shares.
     * @param shares The shares to simulate minting.
     * @return assets The assets that would be required.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets) {
        assets = LibVaultStorage.convertToAssets(shares, true);
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
        if (shares == 0) revert LibVaultStorage.LibVaultStorage__ZeroShares();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 supplyBefore = vs.totalSupply;
        uint256 assetsBefore = totalAssets();

        assets = LibVaultStorage.convertToAssetsAtSnapshot(shares, supplyBefore, assetsBefore, true);
        IERC20(vs.asset).safeTransferFrom(msg.sender, address(this), assets);

        uint256 received = totalAssets() - assetsBefore;
        if (received != assets) {
            revert LibVaultStorage.LibVaultStorage__AssetTransferMismatch(assets, received);
        }

        LibVaultStorage.mintShares(receiver, shares);
        LibReentrancyGuard.exit();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Returns the maximum assets an owner can withdraw.
     * @param owner The share owner to query.
     * @return maxAssets The maximum withdrawable asset amount.
     */
    function maxWithdraw(address owner) external view returns (uint256 maxAssets) {
        if (LibVaultControl.withdrawalsPaused()) {
            return 0;
        }
        uint256 ownerShares = LibVaultStorage.vaultStorage().balances[owner];
        maxAssets = LibVaultStorage.convertToAssets(ownerShares, false);
    }

    /**
     * @notice Returns the shares that would be burned for an asset withdrawal.
     * @param assets The assets to simulate withdrawing.
     * @return shares The shares that would be burned.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares) {
        shares = LibVaultStorage.convertToShares(assets, true);
    }

    /**
     * @notice Burns enough shares to withdraw a target amount of assets.
     * @param assets The amount of assets to withdraw.
     * @param receiver The account that will receive the assets.
     * @param owner The account whose shares will be burned.
     * @return shares The amount of shares burned.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        LibReentrancyGuard.enter();
        LibVaultControl.revertIfWithdrawalsPaused();
        if (assets == 0) revert LibVaultStorage.LibVaultStorage__ZeroAssets();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 minShares = LibVaultStorage.convertToSharesAtSnapshot(assets, vs.totalSupply, totalAssets(), true);
        LibVaultStorage.revertIfCannotSpendShares(owner, msg.sender, minShares);
        LibStrategyStorage.ensureLiquidity(vs.asset, assets, true);
        uint256 supplyBefore = vs.totalSupply;
        uint256 assetsBefore = totalAssets();
        shares = LibVaultStorage.convertToSharesAtSnapshot(assets, supplyBefore, assetsBefore, true);

        if (owner != msg.sender) LibVaultStorage.spendAllowance(owner, msg.sender, shares);
        LibVaultStorage.burnShares(owner, shares);
        IERC20(vs.asset).safeTransfer(receiver, assets);

        LibReentrancyGuard.exit();
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /**
     * @notice Returns the maximum shares an owner can redeem.
     * @param owner The share owner to query.
     * @return maxShares The owner's full share balance.
     */
    function maxRedeem(address owner) external view returns (uint256 maxShares) {
        maxShares = LibVaultControl.withdrawalsPaused() ? 0 : LibVaultStorage.vaultStorage().balances[owner];
    }

    /**
     * @notice Returns the assets that would be received for redeeming shares.
     * @param shares The shares to simulate redeeming.
     * @return assets The assets that would be returned.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets) {
        assets = LibVaultStorage.convertToAssets(shares, false);
    }

    /**
     * @notice Burns shares and transfers the corresponding assets out of the vault.
     * @param shares The amount of shares to redeem.
     * @param receiver The account that will receive the assets.
     * @param owner The account whose shares will be burned.
     * @return assets The amount of assets transferred out.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        LibReentrancyGuard.enter();
        LibVaultControl.revertIfWithdrawalsPaused();
        if (shares == 0) revert LibVaultStorage.LibVaultStorage__ZeroShares();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        LibVaultStorage.revertIfCannotSpendShares(owner, msg.sender, shares);
        uint256 supplyBefore = vs.totalSupply;
        uint256 previewAssets = LibVaultStorage.convertToAssetsAtSnapshot(shares, supplyBefore, totalAssets(), false);
        LibStrategyStorage.ensureLiquidity(vs.asset, previewAssets, false);
        uint256 assetsBefore = totalAssets();
        assets = LibVaultStorage.convertToAssetsAtSnapshot(shares, supplyBefore, assetsBefore, false);

        if (LibVaultStorage.idleAssets() < assets) {
            revert LibStrategyStorage.LibStrategyStorage__InsufficientLiquidity(assets, LibVaultStorage.idleAssets());
        }

        if (owner != msg.sender) LibVaultStorage.spendAllowance(owner, msg.sender, shares);
        LibVaultStorage.burnShares(owner, shares);
        IERC20(vs.asset).safeTransfer(receiver, assets);

        LibReentrancyGuard.exit();
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}
