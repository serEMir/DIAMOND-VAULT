// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CREReceiver
 * @notice Receives signed reports from CRE and executes them on the Diamond vault.
 * @dev Only the authorized CRE forwarder can submit reports.
 */
contract CREReceiver {
    error CREReceiver__UnauthorizedCaller(address caller, address forwarder);
    error CREReceiver__ReportAlreadyExecuted(bytes32 reportId);
    error CREReceiver__DiamondCallFailed(bytes returndata);

    address public immutable i_diamond;
    address public immutable i_creForwarder;

    /// @notice Tracks executed report IDs to prevent replays
    mapping(bytes32 => bool) public executedReports;

    event ReportExecuted(bytes32 indexed reportId, bytes payload);
    event ReportExecutionFailed(bytes32 indexed reportId, bytes payload, string reason);

    constructor(address diamond, address creForwarder) {
        i_diamond = diamond;
        i_creForwarder = creForwarder;
    }

    /**
     * @notice Executes a report from CRE on the Diamond vault.
     * @param reportId Unique identifier for this report (prevents replays)
     * @param payload The encoded function call to execute on the Diamond
     * @dev Only the CRE forwarder can call this function.
     * @dev Each reportId can only be executed once (idempotent).
     */
    function executeReport(bytes32 reportId, bytes calldata payload) external {
        if (msg.sender != i_creForwarder) {
            revert CREReceiver__UnauthorizedCaller(msg.sender, i_creForwarder);
        }
        if (executedReports[reportId]) {
            revert CREReceiver__ReportAlreadyExecuted(reportId);
        }

        // Mark as executed before calling (prevents reentrancy)
        executedReports[reportId] = true;

        (bool success, bytes memory returndata) = i_diamond.call(payload);

        if (!success) {
            revert CREReceiver__DiamondCallFailed(returndata);
        }

        emit ReportExecuted(reportId, payload);
    }

    /**
     * @notice Checks if a report has already been executed.
     * @param reportId The report ID to check
     * @return True if the report has been executed
     */
    function hasExecuted(bytes32 reportId) external view returns (bool) {
        return executedReports[reportId];
    }
}
