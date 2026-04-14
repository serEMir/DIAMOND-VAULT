// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMockStrategyFacet
 * @notice Interface for the mock strategy facet used in strategy integration tests.
 */
interface IMockStrategyFacet {
    /**
     * @notice Emitted when the mock yield source for a strategy is updated.
     * @param strategyId The strategy id whose source changed.
     * @param previousSource The previously configured yield source.
     * @param newSource The newly configured yield source.
     */
    event MockStrategySourceUpdated(
        bytes32 indexed strategyId, address indexed previousSource, address indexed newSource
    );

    /**
     * @notice Sets the mock yield source for a strategy.
     * @param strategyId The strategy id to configure.
     * @param source The yield source contract to associate with the strategy.
     */
    function setMockStrategySource(bytes32 strategyId, address source) external;

    /**
     * @notice Returns the configured mock yield source for a strategy.
     * @param strategyId The strategy id to query.
     * @return source The configured yield source.
     */
    function mockStrategySource(bytes32 strategyId) external view returns (address source);

    /**
     * @notice Deploys assets into the configured mock yield source.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount of assets to deploy.
     * @return deployedAssets The amount of assets reported as deployed.
     */
    function mockStrategyDeploy(bytes32 strategyId, uint256 assets) external returns (uint256 deployedAssets);

    /**
     * @notice Frees assets from the configured mock yield source.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount of assets requested.
     * @return freedAssets The amount of assets actually returned.
     * @return loss The realized loss, if any.
     */
    function mockStrategyFreeFunds(bytes32 strategyId, uint256 assets)
        external
        returns (uint256 freedAssets, uint256 loss);

    /**
     * @notice Returns the assets currently reported by the configured mock yield source.
     * @param strategyId The strategy id to query.
     * @return totalManagedAssets The assets reported for the diamond's position.
     */
    function mockStrategyHarvest(bytes32 strategyId) external view returns (uint256 totalManagedAssets);
}
