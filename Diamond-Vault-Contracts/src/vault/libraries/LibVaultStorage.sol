// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LibStrategyStorage} from "../../strategy/libraries/LibStrategyStorage.sol";

/**
 * @title LibVaultStorage
 * @notice Shared storage and accounting library for the vault facets.
 */
library LibVaultStorage {
    uint8 internal constant SHARE_DECIMALS = 18;

    /**
     * @dev Storage slot used to locate the vault's shared state.
     */
    bytes32 internal constant VAULT_STORAGE_POSITION = keccak256("diamondvault.vault.storage");

    error LibVaultStorage__AlreadyInitialized();
    error LibVaultStorage__AssetAddressIsZero();
    error LibVaultStorage__AddressIsZero();
    error LibVaultStorage__ZeroAssets();
    error LibVaultStorage__ZeroShares();
    error LibVaultStorage__InsufficientBalance(address account, uint256 balance, uint256 amount);
    error LibVaultStorage__InsufficientAllowance(address owner, address spender, uint256 allowance, uint256 amount);
    error LibVaultStorage__VaultInsolvent();
    error LibVaultStorage__AssetTransferMismatch(uint256 expected, uint256 received);
    error LibVaultStorage__AssetDecimalsReadFailed(address asset);

    /**
     * @notice Canonical storage layout used by the vault facets.
     */
    struct VaultStorage {
        address asset;
        uint8 assetDecimals;
        uint8 __reservedShareDecimalsSlot; // Reserved to avoid shifting storage slots after making share decimals a compile-time invariant.
        string name;
        string symbol;
        uint256 totalSupply;
        bool initialized;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @notice Returns the storage pointer for the vault's shared state.
     * @return vs The storage struct located at `VAULT_STORAGE_POSITION`.
     */
    function vaultStorage() internal pure returns (VaultStorage storage vs) {
        bytes32 position = VAULT_STORAGE_POSITION;
        assembly {
            vs.slot := position
        }
    }

    /**
     * @notice Initializes the vault metadata and underlying asset configuration.
     * @param asset_ The underlying asset token managed by the vault.
     * @param name_ The ERC-20 name for the vault shares.
     * @param symbol_ The ERC-20 symbol for the vault shares.
     */
    function initialize(address asset_, string memory name_, string memory symbol_) internal {
        if (asset_ == address(0)) revert LibVaultStorage__AssetAddressIsZero();

        VaultStorage storage vs = vaultStorage();
        if (vs.initialized) revert LibVaultStorage__AlreadyInitialized();

        vs.asset = asset_;
        vs.assetDecimals = _readAssetDecimals(asset_);
        vs.name = name_;
        vs.symbol = symbol_;
        vs.initialized = true;
    }

    /**
     * @notice Returns the amount of underlying assets currently held by the vault.
     * @return The vault's idle asset balance plus reported strategy debt.
     */
    function totalAssets() internal view returns (uint256) {
        return idleAssets() + LibStrategyStorage.totalDebt();
    }

    /**
     * @notice Returns the underlying asset balance currently sitting idle in the vault.
     * @return The idle asset balance.
     */
    function idleAssets() internal view returns (uint256) {
        return IERC20(vaultStorage().asset).balanceOf(address(this));
    }

    /**
     * @notice Converts an asset amount into shares using the current vault totals.
     * @param assets The amount of assets to convert.
     * @param roundUp Whether to round the result up when division leaves a remainder.
     * @return The corresponding amount of shares.
     */
    function convertToShares(uint256 assets, bool roundUp) internal view returns (uint256) {
        VaultStorage storage vs = vaultStorage();
        return _convertToShares(assets, vs.totalSupply, totalAssets(), vs.assetDecimals, roundUp);
    }

    /**
     * @notice Converts a share amount into assets using the current vault totals.
     * @param shares The amount of shares to convert.
     * @param roundUp Whether to round the result up when division leaves a remainder.
     * @return The corresponding amount of assets.
     */
    function convertToAssets(uint256 shares, bool roundUp) internal view returns (uint256) {
        VaultStorage storage vs = vaultStorage();
        return _convertToAssets(shares, vs.totalSupply, totalAssets(), vs.assetDecimals, roundUp);
    }

    /**
     * @notice Converts assets to shares using caller-supplied totals instead of live vault reads.
     * @param assets The amount of assets to convert.
     * @param supply The share supply to use for the conversion.
     * @param assetsBefore The asset total to use for the conversion.
     * @param roundUp Whether to round the result up when division leaves a remainder.
     * @return The corresponding amount of shares.
     */
    function convertToSharesAtSnapshot(uint256 assets, uint256 supply, uint256 assetsBefore, bool roundUp)
        internal
        view
        returns (uint256)
    {
        VaultStorage storage vs = vaultStorage();
        return _convertToShares(assets, supply, assetsBefore, vs.assetDecimals, roundUp);
    }

    /**
     * @notice Converts shares to assets using caller-supplied totals instead of live vault reads.
     * @param shares The amount of shares to convert.
     * @param supply The share supply to use for the conversion.
     * @param assetsBefore The asset total to use for the conversion.
     * @param roundUp Whether to round the result up when division leaves a remainder.
     * @return The corresponding amount of assets.
     */
    function convertToAssetsAtSnapshot(uint256 shares, uint256 supply, uint256 assetsBefore, bool roundUp)
        internal
        view
        returns (uint256)
    {
        VaultStorage storage vs = vaultStorage();
        return _convertToAssets(shares, supply, assetsBefore, vs.assetDecimals, roundUp);
    }

    function shareDecimals() internal pure returns (uint8) {
        return SHARE_DECIMALS;
    }

    /**
     * @notice Returns whether deposits and mints are currently allowed.
     * @return True when the vault is either empty or solvent, otherwise false.
     */
    function isDepositAllowed() internal view returns (bool) {
        VaultStorage storage vs = vaultStorage();
        return !(vs.totalSupply != 0 && totalAssets() == 0);
    }

    /**
     * @notice Mints vault shares to an account.
     * @param to The account that will receive the newly minted shares.
     * @param amount The amount of shares to mint.
     */
    function mintShares(address to, uint256 amount) internal {
        if (to == address(0)) revert LibVaultStorage__AddressIsZero();
        if (amount == 0) revert LibVaultStorage__ZeroShares();

        VaultStorage storage vs = vaultStorage();
        vs.totalSupply += amount;
        vs.balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Burns vault shares from an account.
     * @param from The account whose shares will be burned.
     * @param amount The amount of shares to burn.
     */
    function burnShares(address from, uint256 amount) internal {
        if (from == address(0)) revert LibVaultStorage__AddressIsZero();
        if (amount == 0) revert LibVaultStorage__ZeroShares();

        VaultStorage storage vs = vaultStorage();
        uint256 balance = vs.balances[from];
        if (balance < amount) {
            revert LibVaultStorage__InsufficientBalance(from, balance, amount);
        }

        vs.balances[from] = balance - amount;
        vs.totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    /**
     * @notice Transfers vault shares between accounts.
     * @param from The account to move shares from.
     * @param to The recipient of the shares.
     * @param amount The amount of shares to transfer.
     */
    function transferShares(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert LibVaultStorage__AddressIsZero();

        VaultStorage storage vs = vaultStorage();
        uint256 balance = vs.balances[from];
        if (balance < amount) {
            revert LibVaultStorage__InsufficientBalance(from, balance, amount);
        }

        vs.balances[from] = balance - amount;
        vs.balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    /**
     * @notice Sets a share allowance on behalf of an owner.
     * @param owner The share owner granting the allowance.
     * @param spender The account allowed to spend the shares.
     * @param amount The allowance amount to set.
     */
    function approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert LibVaultStorage__AddressIsZero();

        vaultStorage().allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @notice Consumes an allowance, unless it is already set to the maximum uint256 value.
     * @param owner The share owner whose allowance is being consumed.
     * @param spender The account spending the allowance.
     * @param amount The amount of allowance to consume.
     */
    function spendAllowance(address owner, address spender, uint256 amount) internal {
        VaultStorage storage vs = vaultStorage();
        uint256 currentAllowance = vs.allowances[owner][spender];

        if (currentAllowance == type(uint256).max) {
            return;
        }
        if (currentAllowance < amount) {
            revert LibVaultStorage__InsufficientAllowance(owner, spender, currentAllowance, amount);
        }

        unchecked {
            vs.allowances[owner][spender] = currentAllowance - amount;
        }
        emit Approval(owner, spender, vs.allowances[owner][spender]);
    }

    /**
     * @notice Reverts if `owner` does not currently hold at least `amount` shares.
     * @param owner The account whose share balance should be checked.
     * @param amount The share amount required.
     */
    function revertIfInsufficientBalance(address owner, uint256 amount) internal view {
        uint256 balance = vaultStorage().balances[owner];
        if (balance < amount) {
            revert LibVaultStorage__InsufficientBalance(owner, balance, amount);
        }
    }

    /**
     * @notice Reverts if `spender` does not currently have enough allowance to spend `owner`'s shares.
     * @param owner The account whose share allowance should be checked.
     * @param spender The account attempting to spend the shares.
     * @param amount The share amount required.
     */
    function revertIfInsufficientAllowance(address owner, address spender, uint256 amount) internal view {
        uint256 currentAllowance = vaultStorage().allowances[owner][spender];
        if (currentAllowance != type(uint256).max && currentAllowance < amount) {
            revert LibVaultStorage__InsufficientAllowance(owner, spender, currentAllowance, amount);
        }
    }

    /**
     * @notice Reverts if `spender` cannot currently spend `amount` shares from `owner`.
     * @param owner The account whose shares would be burned or transferred.
     * @param spender The account attempting to spend the shares.
     * @param amount The share amount required.
     */
    function revertIfCannotSpendShares(address owner, address spender, uint256 amount) internal view {
        revertIfInsufficientBalance(owner, amount);
        if (owner != spender) {
            revertIfInsufficientAllowance(owner, spender, amount);
        }
    }

    /**
     * @notice Converts assets into shares using caller-supplied totals and decimal configuration.
     * @param assets The amount of assets to convert.
     * @param supply The share supply to use for the conversion.
     * @param assetsBefore The asset total to use for the conversion.
     * @param assetDecimals The decimals of the underlying asset.
     * @param roundUp Whether to round the result up when division leaves a remainder.
     * @return shares The corresponding amount of shares.
     */
    function _convertToShares(uint256 assets, uint256 supply, uint256 assetsBefore, uint8 assetDecimals, bool roundUp)
        private
        pure
        returns (uint256 shares)
    {
        if (assets == 0) {
            return 0;
        }
        if (supply == 0) {
            return _scaleAssetsToShares(assets, assetDecimals, roundUp);
        }
        if (assetsBefore == 0) revert LibVaultStorage__VaultInsolvent();

        shares = Math.mulDiv(assets, supply, assetsBefore, _rounding(roundUp));
    }

    /**
     * @notice Converts shares into assets using caller-supplied totals and decimal configuration.
     * @param shares The amount of shares to convert.
     * @param supply The share supply to use for the conversion.
     * @param assetsBefore The asset total to use for the conversion.
     * @param assetDecimals The decimals of the underlying asset.
     * @param roundUp Whether to round the result up when division leaves a remainder.
     * @return assets The corresponding amount of assets.
     */
    function _convertToAssets(uint256 shares, uint256 supply, uint256 assetsBefore, uint8 assetDecimals, bool roundUp)
        private
        pure
        returns (uint256 assets)
    {
        if (shares == 0) {
            return 0;
        }
        if (supply == 0) {
            return _scaleSharesToAssets(shares, assetDecimals, roundUp);
        }
        if (assetsBefore == 0) revert LibVaultStorage__VaultInsolvent();

        assets = Math.mulDiv(shares, assetsBefore, supply, _rounding(roundUp));
    }

    /**
     * @notice Scales an asset amount into share units for the initial deposit case.
     * @param assets The asset amount to scale.
     * @param assetDecimals The decimals used by the asset token.
     * @return The scaled share amount.
     */
    function _scaleAssetsToShares(uint256 assets, uint8 assetDecimals, bool roundUp) private pure returns (uint256) {
        return Math.mulDiv(assets, 10 ** SHARE_DECIMALS, 10 ** assetDecimals, _rounding(roundUp));
    }

    /**
     * @notice Scales a share amount into asset units for the zero-supply conversion case.
     * @param shares The share amount to scale.
     * @param assetDecimals The decimals used by the asset token.
     * @return The scaled asset amount.
     */
    function _scaleSharesToAssets(uint256 shares, uint8 assetDecimals, bool roundUp) private pure returns (uint256) {
        return Math.mulDiv(shares, 10 ** assetDecimals, 10 ** SHARE_DECIMALS, _rounding(roundUp));
    }

    /**
     * @notice Reads the decimals reported by the underlying asset token.
     * @param asset_ The asset token to query.
     * @return assetDecimals The decoded decimals value.
     */
    function _readAssetDecimals(address asset_) private view returns (uint8 assetDecimals) {
        try IERC20Metadata(asset_).decimals() returns (uint8 decimals_) {
            assetDecimals = decimals_;
        } catch {
            revert LibVaultStorage__AssetDecimalsReadFailed(asset_);
        }
    }

    function _rounding(bool roundUp) private pure returns (Math.Rounding) {
        return roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor;
    }
}
