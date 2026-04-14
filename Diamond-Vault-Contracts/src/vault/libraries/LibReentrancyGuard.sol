// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibReentrancyGuard
 * @notice Shared reentrancy lock used by asset-moving vault and strategy entrypoints.
 */
library LibReentrancyGuard {
    /**
     * @dev Storage slot used to locate the shared reentrancy guard state.
     */
    bytes32 internal constant REENTRANCY_GUARD_STORAGE_POSITION = keccak256("diamondvault.reentrancy.guard.storage");

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    error LibReentrancyGuard__ReentrantCall();

    struct ReentrancyGuardStorage {
        uint256 status;
    }

    /**
     * @notice Returns the storage pointer for the shared reentrancy guard.
     * @return rgs The storage struct located at `REENTRANCY_GUARD_STORAGE_POSITION`.
     */
    function reentrancyGuardStorage() internal pure returns (ReentrancyGuardStorage storage rgs) {
        bytes32 position = REENTRANCY_GUARD_STORAGE_POSITION;
        assembly {
            rgs.slot := position
        }
    }

    /**
     * @notice Enters the shared reentrancy lock and reverts if it is already held.
     */
    function enter() internal {
        ReentrancyGuardStorage storage rgs = reentrancyGuardStorage();
        if (rgs.status == ENTERED) {
            revert LibReentrancyGuard__ReentrantCall();
        }
        if (rgs.status == 0) {
            rgs.status = NOT_ENTERED;
        }

        rgs.status = ENTERED;
    }

    /**
     * @notice Releases the shared reentrancy lock.
     */
    function exit() internal {
        reentrancyGuardStorage().status = NOT_ENTERED;
    }
}
