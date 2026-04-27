// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title LibVaultStorage_BROKEN
 * @notice INTENTIONALLY BROKEN version with field inserted in the middle of VaultStorage.
 *
 * This demonstrates the storage collision footgun: inserting a field in the middle
 * of the struct causes all subsequent mapping slots to shift, breaking balance access.
 */
library LibVaultStorage_BROKEN {
    uint8 internal constant SHARE_DECIMALS = 18;

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
     * @notice BROKEN STRUCT LAYOUT: Field inserted in the middle!
     *
     * Original layout:
     *   slot 0: address asset
     *   slot 1: uint8 assetDecimals
     *   slot 1: uint8 __reservedShareDecimalsSlot
     *   slot 2: string name
     *   slot 3: string symbol
     *   slot 4: uint256 totalSupply
     *   slot 5: bool initialized
     *   slot 5+: mapping balances (computed as keccak256(account, 5))
     *   slot 6+: mapping allowances (computed as keccak256(account, 6))
     *
     * BROKEN layout (with new field inserted):
     *   slot 0: address asset
     *   slot 1: uint8 assetDecimals
     *   slot 1: uint8 __reservedShareDecimalsSlot
     *   slot 2: string name
     *   slot 3: string symbol
     *   slot 4: uint256 totalSupply
     *   slot 5: bool initialized
     *   slot 5: uint256 newTrackedDeposits  ← INSERTED HERE, BREAKS MAPPING!
     *   slot 6+: mapping balances (now computed as keccak256(account, 6), NOT 5!)
     *   slot 7+: mapping allowances
     *
     * Result: balanceOf(alice) reads from keccak256(alice, 6) instead of keccak256(alice, 5).
     * Alice's balance 1000 shares sits untouched at the old keccak256(alice, 5) location.
     * The new code finds zeros at keccak256(alice, 6).
     */
    struct VaultStorage {
        address asset;
        uint8 assetDecimals;
        uint8 __reservedShareDecimalsSlot;
        string name;
        string symbol;
        uint256 totalSupply;
        bool initialized;
        uint256 newTrackedDeposits; // ← INSERTED HERE: shifts all following mappings!
        mapping(address => uint256) balances; // Now slot 6 instead of 5
        mapping(address => mapping(address => uint256)) allowances; // Now slot 7 instead of 6
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function vaultStorage() internal pure returns (VaultStorage storage vs) {
        bytes32 position = VAULT_STORAGE_POSITION;
        assembly {
            vs.slot := position
        }
    }

    function totalAssets() internal view returns (uint256) {
        VaultStorage storage vs = vaultStorage();
        return IERC20(vs.asset).balanceOf(address(this));
    }

    function idleAssets() internal view returns (uint256) {
        return IERC20(vaultStorage().asset).balanceOf(address(this));
    }

    function convertToShares(uint256 assets, bool roundUp) internal view returns (uint256) {
        uint256 supply = vaultStorage().totalSupply;
        uint256 assetsBefore = totalAssets();
        return _convertToShares(assets, supply, assetsBefore, vaultStorage().assetDecimals, roundUp);
    }

    function convertToAssets(uint256 shares, bool roundUp) internal view returns (uint256) {
        uint256 supply = vaultStorage().totalSupply;
        uint256 assetsBefore = totalAssets();
        return _convertToAssets(shares, supply, assetsBefore, vaultStorage().assetDecimals, roundUp);
    }

    function convertToSharesAtSnapshot(uint256 assets, uint256 supply, uint256 assetsBefore, bool roundUp)
        internal
        view
        returns (uint256)
    {
        return _convertToShares(assets, supply, assetsBefore, vaultStorage().assetDecimals, roundUp);
    }

    function convertToAssetsAtSnapshot(uint256 shares, uint256 supply, uint256 assetsBefore, bool roundUp)
        internal
        view
        returns (uint256)
    {
        return _convertToAssets(shares, supply, assetsBefore, vaultStorage().assetDecimals, roundUp);
    }

    function shareDecimals() internal pure returns (uint8) {
        return SHARE_DECIMALS;
    }

    function isDepositAllowed() internal view returns (bool) {
        return vaultStorage().initialized;
    }

    function mintShares(address to, uint256 amount) internal {
        VaultStorage storage vs = vaultStorage();
        if (amount == 0) revert LibVaultStorage__ZeroShares();
        if (to == address(0)) revert LibVaultStorage__AddressIsZero();
        vs.totalSupply += amount;
        vs.balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burnShares(address from, uint256 amount) internal {
        VaultStorage storage vs = vaultStorage();
        if (amount == 0) revert LibVaultStorage__ZeroShares();
        if (from == address(0)) revert LibVaultStorage__AddressIsZero();
        uint256 balance = vs.balances[from];
        if (balance < amount) revert LibVaultStorage__InsufficientBalance(from, balance, amount);
        vs.balances[from] = balance - amount;
        vs.totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function transferShares(address from, address to, uint256 amount) internal {
        VaultStorage storage vs = vaultStorage();
        if (amount == 0) revert LibVaultStorage__ZeroShares();
        if (from == address(0) || to == address(0)) revert LibVaultStorage__AddressIsZero();
        uint256 balance = vs.balances[from];
        if (balance < amount) revert LibVaultStorage__InsufficientBalance(from, balance, amount);
        vs.balances[from] = balance - amount;
        vs.balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0) || spender == address(0)) revert LibVaultStorage__AddressIsZero();
        vaultStorage().allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function spendAllowance(address owner, address spender, uint256 amount) internal {
        VaultStorage storage vs = vaultStorage();
        uint256 currentAllowance = vs.allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert LibVaultStorage__InsufficientAllowance(owner, spender, currentAllowance, amount);
            }
            vs.allowances[owner][spender] = currentAllowance - amount;
        }
    }

    function revertIfInsufficientBalance(address owner, uint256 amount) internal view {
        uint256 balance = vaultStorage().balances[owner];
        if (balance < amount) revert LibVaultStorage__InsufficientBalance(owner, balance, amount);
    }

    function revertIfInsufficientAllowance(address owner, address spender, uint256 amount) internal view {
        uint256 allowance = vaultStorage().allowances[owner][spender];
        if (allowance < amount) revert LibVaultStorage__InsufficientAllowance(owner, spender, allowance, amount);
    }

    function revertIfCannotSpendShares(address owner, address spender, uint256 amount) internal view {
        revertIfInsufficientBalance(owner, amount);
        if (spender != owner) {
            revertIfInsufficientAllowance(owner, spender, amount);
        }
    }

    function _convertToShares(uint256 assets, uint256, uint256, uint8 assetDecimals, bool roundUp)
        private
        pure
        returns (uint256)
    {
        return _scaleAssetsToShares(assets, assetDecimals, roundUp);
    }

    function _convertToAssets(uint256 shares, uint256, uint256, uint8 assetDecimals, bool roundUp)
        private
        pure
        returns (uint256)
    {
        return Math.mulDiv(shares, 10 ** assetDecimals, 10 ** SHARE_DECIMALS, _rounding(roundUp));
    }

    function _scaleAssetsToShares(uint256 assets, uint8 assetDecimals, bool roundUp) private pure returns (uint256) {
        return Math.mulDiv(assets, 10 ** SHARE_DECIMALS, 10 ** assetDecimals, _rounding(roundUp));
    }

    function _rounding(bool roundUp) private pure returns (Math.Rounding) {
        return roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor;
    }
}
