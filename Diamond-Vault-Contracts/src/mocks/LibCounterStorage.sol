// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibCounterStorage
 * @notice Storage helper library used by the mock counter facets.
 */
library LibCounterStorage {
    /**
     * @dev Storage slot that holds the mock counter state.
     */
    bytes32 internal constant STORAGE_SLOT = keccak256("diamondvault.mock.counter.storage");

    /**
     * @notice Storage layout shared by the mock counter facets.
     */
    struct CounterStorage {
        uint256 counter;
    }

    /**
     * @notice Returns the storage pointer for the mock counter state.
     * @return cs The storage struct located at `STORAGE_SLOT`.
     */
    function counterStorage() internal pure returns (CounterStorage storage cs) {
        bytes32 slot = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            cs.slot := slot
        }
    }
}
