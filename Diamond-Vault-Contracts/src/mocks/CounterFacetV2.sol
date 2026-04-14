// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibCounterStorage} from "./LibCounterStorage.sol";

/**
 * @title CounterFacetV2
 * @notice Replacement mock facet used to prove selector replacement while preserving storage.
 */
contract CounterFacetV2 {
    /**
     * @notice Returns the current counter value.
     * @return The value stored in shared counter storage.
     */
    function counter() external view returns (uint256) {
        return LibCounterStorage.counterStorage().counter;
    }

    /**
     * @notice Increments the counter by two.
     * @dev Uses the same selector as `CounterFacet.increment()` to demonstrate replace cuts.
     */
    function increment() external {
        LibCounterStorage.counterStorage().counter += 2;
    }
}
