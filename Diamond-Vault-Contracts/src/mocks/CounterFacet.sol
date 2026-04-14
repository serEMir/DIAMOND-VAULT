// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibCounterStorage} from "./LibCounterStorage.sol";

/**
 * @title CounterFacet
 * @notice Mock facet that exposes a simple counter used in upgrade and routing tests.
 */
contract CounterFacet {
    /**
     * @notice Returns the current counter value.
     * @return The value stored in shared counter storage.
     */
    function counter() external view returns (uint256) {
        return LibCounterStorage.counterStorage().counter;
    }

    /**
     * @notice Increments the counter by one.
     */
    function increment() external {
        LibCounterStorage.counterStorage().counter += 1;
    }
}
