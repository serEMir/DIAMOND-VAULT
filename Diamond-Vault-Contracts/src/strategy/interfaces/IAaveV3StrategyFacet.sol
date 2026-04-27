// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAaveV3StrategyFacet
 * @notice Interface for the first real Aave V3 lending strategy facet.
 */
interface IAaveV3StrategyFacet {
    /**
     * @notice Emitted when the Aave config for a strategy changes.
     * @param strategyId The strategy being configured.
     * @param previousPool The previous pool address.
     * @param newPool The new pool address.
     * @param previousAToken The previous aToken address.
     * @param newAToken The new aToken address.
     */
    event AaveV3StrategyConfigured(
        bytes32 indexed strategyId,
        address indexed previousPool,
        address indexed newPool,
        address previousAToken,
        address newAToken
    );

    /**
     * @notice Sets the Aave pool and aToken used by a strategy id.
     * @param strategyId The strategy to configure.
     * @param pool The Aave pool address.
     * @param aToken The interest-bearing aToken address.
     */
    function setAaveV3StrategyConfig(bytes32 strategyId, address pool, address aToken) external;

    /**
     * @notice Returns the configured pool and aToken for a strategy.
     * @param strategyId The strategy id to inspect.
     * @return pool The configured pool address.
     * @return aToken The configured aToken address.
     */
    function aaveV3StrategyConfig(bytes32 strategyId) external view returns (address pool, address aToken);

    /**
     * @notice Supplies assets into Aave.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount to supply.
     * @return deployedAssets The amount supplied.
     */
    function aaveV3StrategyDeploy(bytes32 strategyId, uint256 assets) external returns (uint256 deployedAssets);

    /**
     * @notice Pulls assets back from Aave.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount requested.
     * @return freedAssets The amount actually withdrawn.
     * @return loss The realized shortfall, if any.
     */
    function aaveV3StrategyFreeFunds(bytes32 strategyId, uint256 assets)
        external
        returns (uint256 freedAssets, uint256 loss);

    /**
     * @notice Returns the current aToken-backed position size for the diamond.
     * @param strategyId The strategy id to inspect.
     * @return totalManagedAssets The current position value.
     */
    function aaveV3StrategyHarvest(bytes32 strategyId) external view returns (uint256 totalManagedAssets);
}
