// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";

/**
 * @title LibVaultControl
 * @notice Shared storage and guard library for vault pause and guardian controls.
 */
library LibVaultControl {
    /**
     * @dev Storage slot used to locate the vault pause-control state.
     */
    bytes32 internal constant VAULT_CONTROL_STORAGE_POSITION = keccak256("diamondvault.vault.control.storage");

    error LibVaultControl__DepositsPaused();
    error LibVaultControl__WithdrawalsPaused();
    error LibVaultControl__ShareTransfersPaused();
    error LibVaultControl__NotPauseAuthority(address caller, address owner, address guardian);

    /**
     * @notice Canonical storage layout for vault pause and guardian state.
     */
    struct VaultControlStorage {
        bool depositsPaused;
        bool withdrawalsPaused;
        bool shareTransfersPaused;
        address guardian;
    }

    /**
     * @notice Returns the storage pointer for the vault pause-control module.
     * @return vcs The storage struct located at `VAULT_CONTROL_STORAGE_POSITION`.
     */
    function vaultControlStorage() internal pure returns (VaultControlStorage storage vcs) {
        bytes32 position = VAULT_CONTROL_STORAGE_POSITION;
        assembly {
            vcs.slot := position
        }
    }

    /**
     * @notice Returns whether deposits are paused.
     * @return True if deposits are paused.
     */
    function depositsPaused() internal view returns (bool) {
        return vaultControlStorage().depositsPaused;
    }

    /**
     * @notice Returns whether withdrawals are paused.
     * @return True if withdrawals are paused.
     */
    function withdrawalsPaused() internal view returns (bool) {
        return vaultControlStorage().withdrawalsPaused;
    }

    /**
     * @notice Returns whether share transfers are paused.
     * @return True if share transfers are paused.
     */
    function shareTransfersPaused() internal view returns (bool) {
        return vaultControlStorage().shareTransfersPaused;
    }

    /**
     * @notice Returns the configured pause guardian.
     * @return guardian_ The guardian address.
     */
    function guardian() internal view returns (address guardian_) {
        guardian_ = vaultControlStorage().guardian;
    }

    /**
     * @notice Updates the deposits pause flag.
     * @param paused The new deposits pause state.
     */
    function setDepositsPaused(bool paused) internal {
        vaultControlStorage().depositsPaused = paused;
    }

    /**
     * @notice Updates the withdrawals pause flag.
     * @param paused The new withdrawals pause state.
     */
    function setWithdrawalsPaused(bool paused) internal {
        vaultControlStorage().withdrawalsPaused = paused;
    }

    /**
     * @notice Updates the share-transfer pause flag.
     * @param paused The new share-transfer pause state.
     */
    function setShareTransfersPaused(bool paused) internal {
        vaultControlStorage().shareTransfersPaused = paused;
    }

    /**
     * @notice Sets the pause guardian.
     * @param newGuardian The new guardian address.
     * @return previousGuardian The previously configured guardian.
     */
    function setGuardian(address newGuardian) internal returns (address previousGuardian) {
        VaultControlStorage storage vcs = vaultControlStorage();
        previousGuardian = vcs.guardian;
        vcs.guardian = newGuardian;
    }

    /**
     * @notice Reverts unless the caller is allowed to pause vault actions.
     * @dev Both the owner and guardian may pause.
     */
    function enforceCanPause() internal view {
        address owner_ = LibDiamond.contractOwner();
        address guardian_ = guardian();
        if (msg.sender != owner_ && msg.sender != guardian_) {
            revert LibVaultControl__NotPauseAuthority(msg.sender, owner_, guardian_);
        }
    }

    /**
     * @notice Reverts unless the caller is allowed to unpause vault actions.
     * @dev Only the owner may unpause.
     */
    function enforceCanUnpause() internal view {
        LibDiamond.enforceIsContractOwner();
    }

    /**
     * @notice Reverts if deposits are currently paused.
     */
    function revertIfDepositsPaused() internal view {
        if (depositsPaused()) revert LibVaultControl__DepositsPaused();
    }

    /**
     * @notice Reverts if withdrawals are currently paused.
     */
    function revertIfWithdrawalsPaused() internal view {
        if (withdrawalsPaused()) revert LibVaultControl__WithdrawalsPaused();
    }

    /**
     * @notice Reverts if share transfers are currently paused.
     */
    function revertIfShareTransfersPaused() internal view {
        if (shareTransfersPaused()) revert LibVaultControl__ShareTransfersPaused();
    }
}
