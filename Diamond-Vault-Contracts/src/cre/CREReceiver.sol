// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategyKeeper} from "../strategy/interfaces/IStrategyKeeper.sol";
import {IStrategyManager} from "../strategy/interfaces/IStrategyManager.sol";
import {IERC165} from "../diamond/interfaces/IERC165.sol";

interface ICREReceiver {
    function onReport(bytes calldata metadata, bytes calldata report) external;
}

/**
 * @title CREReceiver
 * @notice Receives signed reports from CRE and executes them on the Diamond vault.
 * @dev Only the authorized CRE forwarder can submit reports.
 */
contract CREReceiver {
    error CREReceiver__UnauthorizedCaller(address caller, address forwarder);
    error CREReceiver__ReportAlreadyExecuted(bytes32 reportId);
    error CREReceiver__DiamondCallFailed(bytes returndata);
    error CREReceiver__InvalidReportPayload(bytes payload);
    error CREReceiver__InvalidSelector(bytes4 selector);

    address public immutable i_diamond;
    address public immutable i_creForwarder;

    /// @notice Tracks executed report IDs to prevent replays
    mapping(bytes32 => bool) public executedReports;

    event ReportExecuted(bytes32 indexed reportId, bytes payload);

    constructor(address diamond, address creForwarder) {
        i_diamond = diamond;
        i_creForwarder = creForwarder;
    }

    function onReport(bytes calldata metadata, bytes calldata report) external {
        if (msg.sender != i_creForwarder) {
            revert CREReceiver__UnauthorizedCaller(msg.sender, i_creForwarder);
        }

        bytes32 reportKey = keccak256(abi.encode(metadata, report));
        if (executedReports[reportKey]) {
            revert CREReceiver__ReportAlreadyExecuted(reportKey);
        }

        // Allow harvest (selector + bytes32) or allocate/free (selector + bytes32 + uint256)
        if (report.length != 36 && report.length != 68) {
            revert CREReceiver__InvalidReportPayload(report);
        }

        bytes4 selector = bytes4(report[:4]);
        bool isAllowed = selector == IStrategyKeeper.keeperHarvestStrategy.selector
            || selector == IStrategyManager.allocateToStrategy.selector
            || selector == IStrategyManager.freeFundsFromStrategy.selector;

        if (!isAllowed) {
            revert CREReceiver__InvalidSelector(selector);
        }

        executedReports[reportKey] = true;

        (bool success, bytes memory returndata) = i_diamond.call(report);
        if (!success) {
            revert CREReceiver__DiamondCallFailed(returndata);
        }

        emit ReportExecuted(reportKey, report);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICREReceiver).interfaceId;
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
