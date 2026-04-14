// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {IStrategyManager} from "../interfaces/IStrategyManager.sol";
import {LibStrategyStorage} from "../libraries/LibStrategyStorage.sol";
import {LibReentrancyGuard} from "../../vault/libraries/LibReentrancyGuard.sol";
import {LibVaultControl} from "../../vault/libraries/LibVaultControl.sol";

/**
 * @title StrategyManagerFacet
 * @notice Facet that manages strategy registration, activation, allocation, and harvest flows.
 */
contract StrategyManagerFacet is IStrategyManager {
    /**
     * @notice Returns the ids of all registered strategies.
     * @return ids The registered strategy ids.
     */
    function strategyIds() external view returns (bytes32[] memory ids) {
        ids = LibStrategyStorage.strategyIds();
    }

    /**
     * @notice Returns the aggregate debt tracked across all strategies.
     * @return totalDebt The aggregate strategy debt.
     */
    function totalStrategyDebt() external view returns (uint256 totalDebt) {
        totalDebt = LibStrategyStorage.totalDebt();
    }

    /**
     * @notice Returns the stored configuration and debt state for a strategy.
     * @param strategyId The strategy id to inspect.
     * @return exists Whether the strategy has been registered.
     * @return active Whether the strategy is currently active.
     * @return allocationsPaused Whether new allocations into the strategy are paused.
     * @return frozen Whether the strategy is frozen from harvest and automatic withdrawal use.
     * @return debt The current tracked debt for the strategy.
     * @return deploySelector The selector used to deploy assets.
     * @return freeFundsSelector The selector used to free assets.
     * @return harvestSelector The selector used to harvest strategy state.
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
        )
    {
        LibStrategyStorage.StrategyConfig memory strategy = LibStrategyStorage.strategyState(strategyId);
        return (
            strategy.exists,
            strategy.active,
            strategy.allocationsPaused,
            strategy.frozen,
            strategy.debt,
            strategy.deploySelector,
            strategy.freeFundsSelector,
            strategy.harvestSelector
        );
    }

    /**
     * @notice Registers a new strategy configuration.
     * @param strategyId The identifier to assign to the strategy.
     * @param deploySelector The selector used to deploy assets.
     * @param freeFundsSelector The selector used to free assets.
     * @param harvestSelector The selector used to harvest the strategy.
     */
    function registerStrategy(
        bytes32 strategyId,
        bytes4 deploySelector,
        bytes4 freeFundsSelector,
        bytes4 harvestSelector
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibStrategyStorage.registerStrategy(strategyId, deploySelector, freeFundsSelector, harvestSelector);
        emit StrategyRegistered(strategyId, deploySelector, freeFundsSelector, harvestSelector);
    }

    /**
     * @notice Sets whether a strategy is active.
     * @param strategyId The strategy to update.
     * @param active The new active state.
     */
    function setStrategyActive(bytes32 strategyId, bool active) external {
        LibDiamond.enforceIsContractOwner();
        LibStrategyStorage.setStrategyActive(strategyId, active);
        emit StrategyActivationUpdated(strategyId, active);
    }

    /**
     * @notice Updates the "no new allocations" flag for a strategy.
     * @param strategyId The strategy to update.
     * @param paused The new allocation-pause state.
     */
    function setStrategyAllocationsPaused(bytes32 strategyId, bool paused) external {
        if (paused) {
            LibVaultControl.enforceCanPause();
        } else {
            LibVaultControl.enforceCanUnpause();
        }
        LibStrategyStorage.setStrategyAllocationsPaused(strategyId, paused);
        emit StrategyAllocationPauseUpdated(strategyId, paused);
    }

    /**
     * @notice Updates the frozen state for a strategy.
     * @param strategyId The strategy to update.
     * @param frozen The new frozen state.
     */
    function setStrategyFrozen(bytes32 strategyId, bool frozen) external {
        if (frozen) {
            LibVaultControl.enforceCanPause();
        } else {
            LibVaultControl.enforceCanUnpause();
        }
        LibStrategyStorage.setStrategyFrozen(strategyId, frozen);
        emit StrategyFreezeUpdated(strategyId, frozen);
    }

    /**
     * @notice Allocates assets from the vault into a strategy.
     * @param strategyId The strategy to allocate to.
     * @param assets The amount of assets to deploy.
     * @return deployedAssets The amount of assets reported as deployed.
     */
    function allocateToStrategy(bytes32 strategyId, uint256 assets) external returns (uint256 deployedAssets) {
        LibReentrancyGuard.enter();
        LibDiamond.enforceIsContractOwner();
        deployedAssets = LibStrategyStorage.deployToStrategy(strategyId, assets);
        (,,,, uint256 debt,,,) = this.strategyState(strategyId);
        LibReentrancyGuard.exit();
        emit StrategyAllocated(strategyId, deployedAssets, debt);
    }

    /**
     * @notice Requests assets back from a strategy.
     * @param strategyId The strategy to free assets from.
     * @param assets The amount of assets requested.
     * @return freedAssets The amount of assets returned.
     * @return loss The realized loss, if any.
     */
    function freeFundsFromStrategy(bytes32 strategyId, uint256 assets)
        external
        returns (uint256 freedAssets, uint256 loss)
    {
        LibReentrancyGuard.enter();
        LibDiamond.enforceIsContractOwner();
        (freedAssets, loss) = LibStrategyStorage.freeFundsFromStrategy(strategyId, assets);
        (,,,, uint256 debt,,,) = this.strategyState(strategyId);
        LibReentrancyGuard.exit();
        emit StrategyFundsFreed(strategyId, assets, freedAssets, loss, debt);
    }

    /**
     * @notice Harvests a strategy and synchronizes its tracked debt.
     * @param strategyId The strategy to harvest.
     * @return reportedAssets The assets reported by the strategy.
     * @return gain The realized gain, if any.
     * @return loss The realized loss, if any.
     */
    function harvestStrategy(bytes32 strategyId) external returns (uint256 reportedAssets, uint256 gain, uint256 loss) {
        LibReentrancyGuard.enter();
        LibDiamond.enforceIsContractOwner();
        (,,,, uint256 previousDebt,,,) = this.strategyState(strategyId);
        (reportedAssets, gain, loss) = LibStrategyStorage.harvestStrategy(strategyId);
        LibReentrancyGuard.exit();
        emit StrategyHarvested(strategyId, previousDebt, reportedAssets, gain, loss);
    }
}
