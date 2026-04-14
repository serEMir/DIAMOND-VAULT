// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {IVaultPauseAdmin} from "../interfaces/IVaultPauseAdmin.sol";
import {LibVaultControl} from "../libraries/LibVaultControl.sol";

/**
 * @title VaultPauseFacet
 * @notice Facet that exposes pause-state reads and administrative pause controls for the vault.
 */
contract VaultPauseFacet is IVaultPauseAdmin {
    /**
     * @notice Returns the configured pause guardian.
     * @return guardian_ The guardian address.
     */
    function guardian() external view returns (address guardian_) {
        guardian_ = LibVaultControl.guardian();
    }

    /**
     * @notice Returns whether deposits are currently paused.
     * @return paused True if deposits are paused.
     */
    function depositsPaused() external view returns (bool paused) {
        paused = LibVaultControl.depositsPaused();
    }

    /**
     * @notice Returns whether withdrawals are currently paused.
     * @return paused True if withdrawals are paused.
     */
    function withdrawalsPaused() external view returns (bool paused) {
        paused = LibVaultControl.withdrawalsPaused();
    }

    /**
     * @notice Returns whether share transfers are currently paused.
     * @return paused True if share transfers are paused.
     */
    function shareTransfersPaused() external view returns (bool paused) {
        paused = LibVaultControl.shareTransfersPaused();
    }

    /**
     * @notice Returns the full pause state in a single call.
     * @return depositsPaused_ Whether deposits are paused.
     * @return withdrawalsPaused_ Whether withdrawals are paused.
     * @return shareTransfersPaused_ Whether share transfers are paused.
     */
    function pauseState()
        external
        view
        returns (bool depositsPaused_, bool withdrawalsPaused_, bool shareTransfersPaused_)
    {
        depositsPaused_ = LibVaultControl.depositsPaused();
        withdrawalsPaused_ = LibVaultControl.withdrawalsPaused();
        shareTransfersPaused_ = LibVaultControl.shareTransfersPaused();
    }

    /**
     * @notice Sets the pause guardian.
     * @param newGuardian The new guardian address.
     */
    function setGuardian(address newGuardian) external {
        LibDiamond.enforceIsContractOwner();
        address previousGuardian = LibVaultControl.setGuardian(newGuardian);
        emit GuardianUpdated(previousGuardian, newGuardian);
    }

    /**
     * @notice Updates the deposits pause flag.
     * @param paused The new deposits pause state.
     */
    function setDepositsPaused(bool paused) external {
        _enforcePauseAuthority(paused);
        LibVaultControl.setDepositsPaused(paused);
        emit DepositsPauseUpdated(paused);
    }

    /**
     * @notice Updates the withdrawals pause flag.
     * @param paused The new withdrawals pause state.
     */
    function setWithdrawalsPaused(bool paused) external {
        _enforcePauseAuthority(paused);
        LibVaultControl.setWithdrawalsPaused(paused);
        emit WithdrawalsPauseUpdated(paused);
    }

    /**
     * @notice Updates the share-transfer pause flag.
     * @param paused The new share-transfer pause state.
     */
    function setShareTransfersPaused(bool paused) external {
        _enforcePauseAuthority(paused);
        LibVaultControl.setShareTransfersPaused(paused);
        emit ShareTransfersPauseUpdated(paused);
    }

    /**
     * @notice Enforces the correct authority model for pausing versus unpausing.
     * @param paused The target pause state being applied.
     */
    function _enforcePauseAuthority(bool paused) private view {
        if (paused) {
            LibVaultControl.enforceCanPause();
            return;
        }

        LibVaultControl.enforceCanUnpause();
    }
}
