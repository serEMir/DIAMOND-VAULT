// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LibStrategyStorage
 * @notice Shared storage and accounting library for vault strategies.
 */
library LibStrategyStorage {
    /**
     * @dev Storage slot used to locate the strategy manager's shared state.
     */
    bytes32 internal constant STRATEGY_STORAGE_POSITION = keccak256("diamondvault.strategy.storage");

    error LibStrategyStorage__AlreadyRegistered(bytes32 strategyId);
    error LibStrategyStorage__StrategyNotFound(bytes32 strategyId);
    error LibStrategyStorage__StrategyInactive(bytes32 strategyId);
    error LibStrategyStorage__StrategyAllocationsPaused(bytes32 strategyId);
    error LibStrategyStorage__StrategyFrozen(bytes32 strategyId);
    error LibStrategyStorage__ZeroAssets();
    error LibStrategyStorage__InsufficientLiquidity(uint256 requestedAssets, uint256 availableAssets);
    error LibStrategyStorage__InvalidStrategyAccounting(
        bytes32 strategyId, uint256 requestedAssets, uint256 freedAssets, uint256 loss
    );

    /**
     * @notice Stored configuration and accounting data for a single strategy.
     */
    struct StrategyConfig {
        bool exists;
        bool active;
        bytes4 deploySelector;
        bytes4 freeFundsSelector;
        bytes4 harvestSelector;
        uint256 debt;
        bool allocationsPaused;
        bool frozen;
    }

    /**
     * @notice Canonical storage layout for the strategy module.
     */
    struct StrategyStorage {
        bytes32[] strategyIds;
        mapping(bytes32 => StrategyConfig) strategies;
        uint256 totalDebt;
        address creExecutor;
    }

    /**
     * @notice Returns the storage pointer for the strategy module.
     * @return ss The storage struct located at `STRATEGY_STORAGE_POSITION`.
     */
    function strategyStorage() internal pure returns (StrategyStorage storage ss) {
        bytes32 position = STRATEGY_STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
    }

    /**
     * @notice Returns the ids of all registered strategies.
     * @return ids The registered strategy ids.
     */
    function strategyIds() internal view returns (bytes32[] memory ids) {
        ids = strategyStorage().strategyIds;
    }

    /**
     * @notice Returns the total debt tracked across all strategies.
     * @return totalDebt_ The aggregate strategy debt.
     */
    function totalDebt() internal view returns (uint256 totalDebt_) {
        totalDebt_ = strategyStorage().totalDebt;
    }

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
    ) internal {
        StrategyStorage storage ss = strategyStorage();
        if (ss.strategies[strategyId].exists) revert LibStrategyStorage__AlreadyRegistered(strategyId);

        ss.strategyIds.push(strategyId);
        ss.strategies[strategyId] = StrategyConfig({
            exists: true,
            active: false,
            deploySelector: deploySelector,
            freeFundsSelector: freeFundsSelector,
            harvestSelector: harvestSelector,
            debt: 0,
            allocationsPaused: false,
            frozen: false
        });
    }

    /**
     * @notice Sets whether a strategy is active.
     * @param strategyId The strategy to update.
     * @param active The new active state.
     */
    function setStrategyActive(bytes32 strategyId, bool active) internal {
        StrategyConfig storage strategy = _strategy(strategyId);
        strategy.active = active;
    }

    /**
     * @notice Sets whether new allocations into a strategy are paused.
     * @param strategyId The strategy to update.
     * @param paused The new allocation-pause state.
     */
    function setStrategyAllocationsPaused(bytes32 strategyId, bool paused) internal {
        StrategyConfig storage strategy = _strategy(strategyId);
        strategy.allocationsPaused = paused;
    }

    /**
     * @notice Sets whether a strategy is frozen from harvest and automatic withdrawal use.
     * @param strategyId The strategy to update.
     * @param frozen The new frozen state.
     */
    function setStrategyFrozen(bytes32 strategyId, bool frozen) internal {
        StrategyConfig storage strategy = _strategy(strategyId);
        strategy.frozen = frozen;
    }

    /**
     * @notice Returns the stored state for a strategy.
     * @param strategyId The strategy to inspect.
     * @return strategy The strategy configuration and debt state.
     */
    function strategyState(bytes32 strategyId) internal view returns (StrategyConfig memory strategy) {
        strategy = _strategy(strategyId);
    }

    /**
     * @notice Deploys assets to an active strategy and increases its debt by the deployed amount.
     * @param strategyId The strategy to allocate to.
     * @param assets The amount of assets to deploy.
     * @return deployedAssets The amount reported as deployed by the strategy call.
     */
    function deployToStrategy(bytes32 strategyId, uint256 assets) internal returns (uint256 deployedAssets) {
        if (assets == 0) revert LibStrategyStorage__ZeroAssets();

        StrategyConfig storage strategy = _allocatableStrategy(strategyId);
        deployedAssets = _callDeploy(strategy, strategyId, assets);
        _increaseDebt(strategy, deployedAssets);
    }

    /**
     * @notice Requests assets back from a strategy and decreases debt by the assets freed plus any realized loss.
     * @param strategyId The strategy to free assets from.
     * @param assets The amount of assets requested.
     * @return freedAssets The amount of assets actually returned.
     * @return loss The loss realized while freeing funds, if any.
     */
    function freeFundsFromStrategy(bytes32 strategyId, uint256 assets)
        internal
        returns (uint256 freedAssets, uint256 loss)
    {
        if (assets == 0) {
            return (0, 0);
        }

        StrategyConfig storage strategy = _strategy(strategyId);
        uint256 requestedAssets = assets > strategy.debt ? strategy.debt : assets;
        if (requestedAssets == 0) {
            return (0, 0);
        }

        (freedAssets, loss) = _callFree(strategy, strategyId, requestedAssets);
        if (freedAssets + loss > requestedAssets) {
            revert LibStrategyStorage__InvalidStrategyAccounting(strategyId, requestedAssets, freedAssets, loss);
        }

        _decreaseDebt(strategy, freedAssets + loss);
    }

    /**
     * @notice Harvests a strategy and synchronizes tracked debt with the strategy's reported assets.
     * @param strategyId The strategy to harvest.
     * @return reportedAssets The assets reported by the strategy.
     * @return gain The realized gain, if any.
     * @return loss The realized loss, if any.
     */
    function harvestStrategy(bytes32 strategyId) internal returns (uint256 reportedAssets, uint256 gain, uint256 loss) {
        StrategyConfig storage strategy = _strategy(strategyId);
        if (strategy.frozen) revert LibStrategyStorage__StrategyFrozen(strategyId);
        reportedAssets = _callHarvest(strategy, strategyId);
        (gain, loss) = _syncDebt(strategy, reportedAssets);
    }

    /**
     * @notice Ensures enough liquid assets are available, optionally freeing funds from strategies to do so.
     * @param asset The asset token held by the vault.
     * @param requiredAssets The desired liquid asset amount.
     * @param requireFullAmount Whether to revert if the full amount cannot be made liquid.
     * @return availableAssets The liquid assets available after attempting to free funds.
     */
    function ensureLiquidity(address asset, uint256 requiredAssets, bool requireFullAmount)
        internal
        returns (uint256 availableAssets)
    {
        availableAssets = IERC20(asset).balanceOf(address(this));
        if (availableAssets >= requiredAssets) {
            return availableAssets;
        }

        StrategyStorage storage ss = strategyStorage();
        uint256 strategiesLength = ss.strategyIds.length;
        for (uint256 i; i < strategiesLength; i++) {
            bytes32 strategyId = ss.strategyIds[i];
            StrategyConfig storage strategy = ss.strategies[strategyId];
            if (!strategy.exists || strategy.debt == 0 || strategy.frozen) {
                continue;
            }

            uint256 requestedAssets = requiredAssets - availableAssets;
            if (requestedAssets > strategy.debt) {
                requestedAssets = strategy.debt;
            }

            (uint256 freedAssets,) = freeFundsFromStrategy(strategyId, requestedAssets);
            availableAssets += freedAssets;
            if (availableAssets >= requiredAssets) {
                break;
            }
        }

        if (requireFullAmount && availableAssets < requiredAssets) {
            revert LibStrategyStorage__InsufficientLiquidity(requiredAssets, availableAssets);
        }
    }

    /**
     * @notice Returns a registered strategy or reverts if it does not exist.
     * @param strategyId The strategy id to resolve.
     * @return strategy The resolved strategy storage pointer.
     */
    function _strategy(bytes32 strategyId) private view returns (StrategyConfig storage strategy) {
        strategy = strategyStorage().strategies[strategyId];
        if (!strategy.exists) revert LibStrategyStorage__StrategyNotFound(strategyId);
    }

    /**
     * @notice Returns an active strategy or reverts if it is inactive.
     * @param strategyId The strategy id to resolve.
     * @return strategy The resolved active strategy storage pointer.
     */
    function _activeStrategy(bytes32 strategyId) private view returns (StrategyConfig storage strategy) {
        strategy = _strategy(strategyId);
        if (!strategy.active) revert LibStrategyStorage__StrategyInactive(strategyId);
    }

    /**
     * @notice Returns a strategy that can currently receive new allocations.
     * @param strategyId The strategy id to resolve.
     * @return strategy The resolved strategy storage pointer.
     */
    function _allocatableStrategy(bytes32 strategyId) private view returns (StrategyConfig storage strategy) {
        strategy = _activeStrategy(strategyId);
        if (strategy.allocationsPaused) revert LibStrategyStorage__StrategyAllocationsPaused(strategyId);
        if (strategy.frozen) revert LibStrategyStorage__StrategyFrozen(strategyId);
    }

    /**
     * @notice Increases a strategy's debt and the aggregate strategy debt.
     * @param strategy The strategy storage pointer.
     * @param amount The amount of debt to add.
     */
    function _increaseDebt(StrategyConfig storage strategy, uint256 amount) private {
        strategy.debt += amount;
        strategyStorage().totalDebt += amount;
    }

    /**
     * @notice Decreases a strategy's debt and the aggregate strategy debt.
     * @param strategy The strategy storage pointer.
     * @param amount The amount of debt to remove.
     */
    function _decreaseDebt(StrategyConfig storage strategy, uint256 amount) private {
        strategy.debt -= amount;
        strategyStorage().totalDebt -= amount;
    }

    /**
     * @notice Synchronizes tracked debt to a newly reported strategy debt amount.
     * @param strategy The strategy storage pointer.
     * @param newDebt The debt amount newly reported by the strategy.
     * @return gain The realized gain, if any.
     * @return loss The realized loss, if any.
     */
    function _syncDebt(StrategyConfig storage strategy, uint256 newDebt) private returns (uint256 gain, uint256 loss) {
        StrategyStorage storage ss = strategyStorage();
        uint256 previousDebt = strategy.debt;

        if (newDebt > previousDebt) {
            gain = newDebt - previousDebt;
            ss.totalDebt += gain;
        } else {
            loss = previousDebt - newDebt;
            ss.totalDebt -= loss;
        }

        strategy.debt = newDebt;
    }

    /**
     * @notice Calls the strategy's deploy selector on the diamond and decodes the deployed amount.
     * @param strategy The strategy configuration to use.
     * @param strategyId The strategy identifier passed through to the facet call.
     * @param assets The amount of assets to deploy.
     * @return deployedAssets The amount reported as deployed.
     */
    function _callDeploy(StrategyConfig storage strategy, bytes32 strategyId, uint256 assets)
        private
        returns (uint256 deployedAssets)
    {
        bytes memory result = _callStrategy(strategy.deploySelector, abi.encode(strategyId, assets));
        deployedAssets = abi.decode(result, (uint256));
    }

    /**
     * @notice Calls the strategy's free-funds selector on the diamond and decodes the result.
     * @param strategy The strategy configuration to use.
     * @param strategyId The strategy identifier passed through to the facet call.
     * @param assets The amount of assets requested.
     * @return freedAssets The amount of assets freed.
     * @return loss The realized loss, if any.
     */
    function _callFree(StrategyConfig storage strategy, bytes32 strategyId, uint256 assets)
        private
        returns (uint256 freedAssets, uint256 loss)
    {
        bytes memory result = _callStrategy(strategy.freeFundsSelector, abi.encode(strategyId, assets));
        (freedAssets, loss) = abi.decode(result, (uint256, uint256));
    }

    /**
     * @notice Calls the strategy's harvest selector on the diamond and decodes the reported assets.
     * @param strategy The strategy configuration to use.
     * @param strategyId The strategy identifier passed through to the facet call.
     * @return reportedAssets The assets reported by the strategy.
     */
    function _callHarvest(StrategyConfig storage strategy, bytes32 strategyId)
        private
        returns (uint256 reportedAssets)
    {
        bytes memory result = _callStrategy(strategy.harvestSelector, abi.encode(strategyId));
        reportedAssets = abi.decode(result, (uint256));
    }

    /**
     * @notice Performs a low-level self-call into the diamond and bubbles up any revert data unchanged.
     * @param selector The selector to call on the diamond.
     * @param args The ABI-encoded arguments to append after the selector.
     * @return result The raw returndata from the call.
     */
    function _callStrategy(bytes4 selector, bytes memory args) private returns (bytes memory result) {
        (bool success, bytes memory returndata) = address(this).call(bytes.concat(selector, args));
        if (!success) {
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }
        return returndata;
    }

    /**
     * @notice Returns the configured CRE executor address.
     * @return executor The CRE executor address stored in strategy storage.
     */
    function creExecutor() internal view returns (address executor) {
        executor = strategyStorage().creExecutor;
    }

    /**
     * @notice Sets the CRE executor address in storage and returns the previous value.
     * @param newExecutor The address to set as the CRE executor.
     * @return previous The previous CRE executor address.
     */
    function setCreExecutor(address newExecutor) internal returns (address previous) {
        StrategyStorage storage ss = strategyStorage();
        previous = ss.creExecutor;
        ss.creExecutor = newExecutor;
    }
}
