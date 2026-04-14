// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStrategyManager
 * @notice Interface for registering strategies and managing vault allocations to them.
 */
interface IStrategyManager {
    /**
     * @notice Emitted when a strategy configuration is first registered.
     * @param strategyId The identifier used to address the strategy.
     * @param deploySelector The selector used to deploy assets into the strategy.
     * @param freeFundsSelector The selector used to pull assets back from the strategy.
     * @param harvestSelector The selector used to refresh the strategy's reported debt.
     */
    event StrategyRegistered(
        bytes32 indexed strategyId, bytes4 deploySelector, bytes4 freeFundsSelector, bytes4 harvestSelector
    );

    /**
     * @notice Emitted when a strategy's active flag changes.
     * @param strategyId The identifier of the strategy being updated.
     * @param active The new activation state.
     */
    event StrategyActivationUpdated(bytes32 indexed strategyId, bool active);

    /**
     * @notice Emitted when the "no new allocations" flag changes for a strategy.
     * @param strategyId The identifier of the strategy being updated.
     * @param paused The new allocation-pause state.
     */
    event StrategyAllocationPauseUpdated(bytes32 indexed strategyId, bool paused);

    /**
     * @notice Emitted when the frozen flag changes for a strategy.
     * @param strategyId The identifier of the strategy being updated.
     * @param frozen The new frozen state.
     */
    event StrategyFreezeUpdated(bytes32 indexed strategyId, bool frozen);

    /**
     * @notice Emitted after assets are allocated to a strategy.
     * @param strategyId The identifier of the strategy that received assets.
     * @param assets The amount of assets deployed.
     * @param newDebt The strategy debt after the allocation.
     */
    event StrategyAllocated(bytes32 indexed strategyId, uint256 assets, uint256 newDebt);

    /**
     * @notice Emitted after an attempt to free assets from a strategy.
     * @param strategyId The identifier of the strategy that freed funds.
     * @param requestedAssets The amount of assets requested.
     * @param freedAssets The amount of assets actually returned.
     * @param loss The amount of loss realized while freeing funds.
     * @param newDebt The strategy debt after the operation.
     */
    event StrategyFundsFreed(
        bytes32 indexed strategyId, uint256 requestedAssets, uint256 freedAssets, uint256 loss, uint256 newDebt
    );

    /**
     * @notice Emitted after a strategy's reported assets are harvested and debt is synchronized.
     * @param strategyId The identifier of the harvested strategy.
     * @param previousDebt The debt tracked before the harvest.
     * @param reportedDebt The debt reported by the strategy after harvest.
     * @param gain The realized gain, if any.
     * @param loss The realized loss, if any.
     */
    event StrategyHarvested(
        bytes32 indexed strategyId, uint256 previousDebt, uint256 reportedDebt, uint256 gain, uint256 loss
    );

    /**
     * @notice Returns the ids of all registered strategies.
     * @return ids The registered strategy ids.
     */
    function strategyIds() external view returns (bytes32[] memory ids);

    /**
     * @notice Returns the sum of debt tracked across every strategy.
     * @return totalDebt The aggregate strategy debt.
     */
    function totalStrategyDebt() external view returns (uint256 totalDebt);

    /**
     * @notice Returns the stored configuration and debt state for a strategy.
     * @param strategyId The strategy id to inspect.
     * @return exists Whether the strategy has been registered.
     * @return active Whether the strategy is currently active.
     * @return allocationsPaused Whether new allocations into the strategy are paused.
     * @return frozen Whether the strategy is quarantined from harvest and automatic withdrawal use.
     * @return debt The debt currently attributed to the strategy.
     * @return deploySelector The selector used to deploy funds into the strategy.
     * @return freeFundsSelector The selector used to free funds from the strategy.
     * @return harvestSelector The selector used to harvest or resync the strategy.
     */
    function strategyState(bytes32 strategyId)
        external
        view
        returns (
            bool exists,
            bool active,
            bool allocationsPaused,
            bool frozen,
            uint256 debt,
            bytes4 deploySelector,
            bytes4 freeFundsSelector,
            bytes4 harvestSelector
        );

    /**
     * @notice Registers a new strategy configuration.
     * @param strategyId The identifier to assign to the strategy.
     * @param deploySelector The selector used to deploy assets.
     * @param freeFundsSelector The selector used to free assets.
     * @param harvestSelector The selector used to harvest the strategy state.
     */
    function registerStrategy(
        bytes32 strategyId,
        bytes4 deploySelector,
        bytes4 freeFundsSelector,
        bytes4 harvestSelector
    ) external;

    /**
     * @notice Sets whether a registered strategy is active.
     * @param strategyId The strategy to update.
     * @param active The new active state.
     */
    function setStrategyActive(bytes32 strategyId, bool active) external;

    /**
     * @notice Pauses or unpauses new allocations into a strategy.
     * @param strategyId The strategy to update.
     * @param paused The new allocation-pause state.
     */
    function setStrategyAllocationsPaused(bytes32 strategyId, bool paused) external;

    /**
     * @notice Freezes or unfreezes a strategy.
     * @param strategyId The strategy to update.
     * @param frozen The new frozen state.
     */
    function setStrategyFrozen(bytes32 strategyId, bool frozen) external;

    /**
     * @notice Deploys vault assets into a strategy.
     * @param strategyId The strategy to allocate assets to.
     * @param assets The amount of assets to deploy.
     * @return deployedAssets The amount of assets reported as deployed.
     */
    function allocateToStrategy(bytes32 strategyId, uint256 assets) external returns (uint256 deployedAssets);

    /**
     * @notice Requests assets back from a strategy.
     * @param strategyId The strategy to free assets from.
     * @param assets The amount of assets requested.
     * @return freedAssets The amount of assets returned.
     * @return loss The realized loss, if any.
     */
    function freeFundsFromStrategy(bytes32 strategyId, uint256 assets)
        external
        returns (uint256 freedAssets, uint256 loss);

    /**
     * @notice Harvests a strategy and synchronizes its reported debt.
     * @param strategyId The strategy to harvest.
     * @return reportedAssets The assets reported by the strategy after harvest.
     * @return gain The realized gain, if any.
     * @return loss The realized loss, if any.
     */
    function harvestStrategy(bytes32 strategyId) external returns (uint256 reportedAssets, uint256 gain, uint256 loss);
}
