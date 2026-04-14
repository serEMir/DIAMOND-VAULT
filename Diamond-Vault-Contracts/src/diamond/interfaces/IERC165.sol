// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC165
 * @notice Standard interface for ERC-165 interface detection.
 */
interface IERC165 {
    /**
     * @notice Returns whether an interface is supported.
     * @param interfaceId The ERC-165 interface identifier to query.
     * @return supported True if the interface is supported, otherwise false.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
