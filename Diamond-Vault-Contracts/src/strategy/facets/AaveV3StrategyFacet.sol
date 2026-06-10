// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {IAavePool} from "../interfaces/IAavePool.sol";
import {IAaveV3StrategyFacet} from "../interfaces/IAaveV3StrategyFacet.sol";
import {LibAaveV3StrategyStorage} from "../libraries/LibAaveV3StrategyStorage.sol";
import {LibVaultStorage} from "../../vault/libraries/LibVaultStorage.sol";
import {IAaveAToken} from "../interfaces/IAaveAToken.sol";
import {LibStrategyStorage} from "../libraries/LibStrategyStorage.sol";

/**
 * @title AaveV3StrategyFacet
 * @notice First real strategy facet: supplies the vault asset into Aave V3 and tracks the aToken position.
 */
contract AaveV3StrategyFacet is IAaveV3StrategyFacet {
    using SafeERC20 for IERC20;

    // =======================================================================
    // Errors
    // =======================================================================
    error AaveV3StrategyFacet__OnlyDiamond();
    error AaveV3StrategyFacet__StrategyConfigLocked(bytes32 strategyId, uint256 debt, uint256 aTokenBalance);
    error AaveV3StrategyFacet__PoolHasNoCode(address pool);
    error AaveV3StrategyFacet__ATokenHasNoCode(address aToken);
    error AaveV3StrategyFacet__ATokenUnderlyingMismatch(bytes32 strategyId, address expected, address actual);
    error AaveV3StrategyFacet__ATokenPoolMismatch(bytes32 strategyId, address expected, address actual);
    error AaveV3StrategyFacet__StrategyNotRegistered(bytes32 strategyId);

    /**
     * @notice Sets the pool and aToken addresses for a strategy id.
     * @param strategyId The strategy to configure.
     * @param pool The Aave pool address.
     * @param aToken The aToken address.
     */
    function setAaveV3StrategyConfig(bytes32 strategyId, address pool, address aToken) external {
        LibDiamond.enforceIsContractOwner();
        _validateConfigChange(strategyId, pool, aToken);

        (address previousPool, address previousAToken) = LibAaveV3StrategyStorage.setConfig(strategyId, pool, aToken);
        emit AaveV3StrategyConfigured(strategyId, previousPool, pool, previousAToken, aToken);
    }

    /**
     * @notice Returns the configured Aave addresses for a strategy id.
     * @param strategyId The strategy id to inspect.
     * @return pool The configured pool address.
     * @return aToken The configured aToken address.
     */
    function aaveV3StrategyConfig(bytes32 strategyId) external view returns (address pool, address aToken) {
        LibAaveV3StrategyStorage.AaveV3StrategyConfig memory config = LibAaveV3StrategyStorage.configOf(strategyId);
        return (config.pool, config.aToken);
    }

    /**
     * @notice Supplies vault assets into Aave.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount to supply.
     * @return deployedAssets The amount supplied.
     */
    function aaveV3StrategyDeploy(bytes32 strategyId, uint256 assets) external returns (uint256 deployedAssets) {
        _enforceOnlyDiamond();

        LibAaveV3StrategyStorage.AaveV3StrategyConfig memory config = LibAaveV3StrategyStorage.configOf(strategyId);
        IERC20 asset = IERC20(LibVaultStorage.vaultStorage().asset);
        asset.forceApprove(config.pool, assets);
        IAavePool(config.pool).supply(address(asset), assets, address(this), 0);
        asset.forceApprove(config.pool, 0);

        return assets;
    }

    /**
     * @notice Withdraws assets from Aave.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount requested.
     * @return freedAssets The amount actually withdrawn.
     * @return loss The realized shortfall, if any.
     */
    function aaveV3StrategyFreeFunds(bytes32 strategyId, uint256 assets)
        external
        returns (uint256 freedAssets, uint256 loss)
    {
        _enforceOnlyDiamond();

        LibAaveV3StrategyStorage.AaveV3StrategyConfig memory config = LibAaveV3StrategyStorage.configOf(strategyId);

        freedAssets = IAavePool(config.pool).withdraw(LibVaultStorage.vaultStorage().asset, assets, address(this));

        loss = 0;
    }

    /**
     * @notice Reads the current aToken balance of the diamond.
     * @param strategyId The strategy id to inspect.
     * @return totalManagedAssets The current Aave-backed position size.
     */
    function aaveV3StrategyHarvest(bytes32 strategyId) external view returns (uint256 totalManagedAssets) {
        _enforceOnlyDiamond();

        LibAaveV3StrategyStorage.AaveV3StrategyConfig memory config = LibAaveV3StrategyStorage.configOf(strategyId);
        totalManagedAssets = IERC20(config.aToken).balanceOf(address(this));
    }

    function _enforceOnlyDiamond() private view {
        if (msg.sender != address(this)) revert AaveV3StrategyFacet__OnlyDiamond();
    }

    function _validateConfigChange(bytes32 strategyId, address pool, address aToken) private view {
        if (pool.code.length == 0) revert AaveV3StrategyFacet__PoolHasNoCode(pool);
        if (aToken.code.length == 0) revert AaveV3StrategyFacet__ATokenHasNoCode(aToken);

        LibStrategyStorage.StrategyStorage storage ss = LibStrategyStorage.strategyStorage();
        LibStrategyStorage.StrategyConfig storage strategy = ss.strategies[strategyId];
        if (!strategy.exists) revert AaveV3StrategyFacet__StrategyNotRegistered(strategyId);

        LibAaveV3StrategyStorage.AaveV3StrategyStorage storage avs = LibAaveV3StrategyStorage.aaveV3StrategyStorage();
        LibAaveV3StrategyStorage.AaveV3StrategyConfig storage currentConfig = avs.strategies[strategyId];

        uint256 currentATokenBalance =
            currentConfig.aToken == address(0) ? 0 : IERC20(currentConfig.aToken).balanceOf(address(this));

        if ((strategy.debt != 0) || currentATokenBalance != 0) {
            revert AaveV3StrategyFacet__StrategyConfigLocked(strategyId, strategy.debt, currentATokenBalance);
        }

        address expectedAsset = LibVaultStorage.vaultStorage().asset;
        address actualUnderlying = IAaveAToken(aToken).UNDERLYING_ASSET_ADDRESS();

        if (actualUnderlying != expectedAsset) {
            revert AaveV3StrategyFacet__ATokenUnderlyingMismatch(strategyId, expectedAsset, actualUnderlying);
        }

        address actualPool = IAaveAToken(aToken).POOL();
        if (actualPool != pool) {
            revert AaveV3StrategyFacet__ATokenPoolMismatch(strategyId, pool, actualPool);
        }
    }
}
