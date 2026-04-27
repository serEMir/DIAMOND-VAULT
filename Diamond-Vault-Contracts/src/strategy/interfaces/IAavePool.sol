// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAavePool
 * @notice Minimal subset of the Aave V3 pool interface used by the first lending strategy.
 */
interface IAavePool {
    /**
     * @notice Supplies underlying into Aave and mints aTokens to `onBehalfOf`.
     * @param asset The underlying asset address.
     * @param amount The amount to supply.
     * @param onBehalfOf The receiver of the aTokens.
     * @param referralCode Integrator referral code, set to zero here.
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    /**
     * @notice Withdraws underlying from Aave by burning the caller's aTokens.
     * @param asset The underlying asset address.
     * @param amount The amount of underlying requested.
     * @param to The receiver of the withdrawn underlying.
     * @return withdrawnAmount The amount of underlying actually withdrawn.
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256 withdrawnAmount);
}
