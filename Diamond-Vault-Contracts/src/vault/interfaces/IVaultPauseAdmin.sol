// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVaultPauseAdmin
 * @notice Interface for reading and administering vault pause state.
 */
interface IVaultPauseAdmin {
    /**
     * @notice Emitted when the deposits pause flag changes.
     * @param paused The new deposits pause state.
     */
    event DepositsPauseUpdated(bool paused);

    /**
     * @notice Emitted when the withdrawals pause flag changes.
     * @param paused The new withdrawals pause state.
     */
    event WithdrawalsPauseUpdated(bool paused);

    /**
     * @notice Emitted when the share-transfer pause flag changes.
     * @param paused The new share-transfer pause state.
     */
    event ShareTransfersPauseUpdated(bool paused);

    /**
     * @notice Emitted when the pause guardian changes.
     * @param previousGuardian The previously configured guardian.
     * @param newGuardian The newly configured guardian.
     */
    event GuardianUpdated(address indexed previousGuardian, address indexed newGuardian);

    /**
     * @notice Returns the pause guardian.
     * @return guardian_ The configured guardian address.
     */
    function guardian() external view returns (address guardian_);

    /**
     * @notice Returns whether deposits are currently paused.
     * @return paused True if deposits are paused.
     */
    function depositsPaused() external view returns (bool paused);

    /**
     * @notice Returns whether withdrawals are currently paused.
     * @return paused True if withdrawals are paused.
     */
    function withdrawalsPaused() external view returns (bool paused);

    /**
     * @notice Returns whether share transfers are currently paused.
     * @return paused True if share transfers are paused.
     */
    function shareTransfersPaused() external view returns (bool paused);

    /**
     * @notice Returns the full pause state in a single call.
     * @return depositsPaused_ Whether deposits are paused.
     * @return withdrawalsPaused_ Whether withdrawals are paused.
     * @return shareTransfersPaused_ Whether share transfers are paused.
     */
    function pauseState()
        external
        view
        returns (bool depositsPaused_, bool withdrawalsPaused_, bool shareTransfersPaused_);

    /**
     * @notice Sets the pause guardian.
     * @param newGuardian The new guardian address.
     */
    function setGuardian(address newGuardian) external;

    /**
     * @notice Updates the deposits pause flag.
     * @param paused The new deposits pause state.
     */
    function setDepositsPaused(bool paused) external;

    /**
     * @notice Updates the withdrawals pause flag.
     * @param paused The new withdrawals pause state.
     */
    function setWithdrawalsPaused(bool paused) external;

    /**
     * @notice Updates the share-transfer pause flag.
     * @param paused The new share-transfer pause state.
     */
    function setShareTransfersPaused(bool paused) external;
}
