// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IERC173
 * @notice EIP-173 ownership interface commonly exposed by diamonds and other ownable contracts.
 */
interface IERC173 {
    /**
     * @notice Emitted when ownership is transferred.
     * @param previousOwner The address that previously controlled the contract.
     * @param newOwner The address that now controls the contract.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Returns the current owner.
     * @return owner_ The owner address.
     */
    function owner() external view returns (address owner_);

    /**
     * @notice Transfers ownership to a new account.
     * @param newOwner The account that will become the new owner.
     */
    function transferOwnership(address newOwner) external;
}
