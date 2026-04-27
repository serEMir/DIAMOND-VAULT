// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibAaveV3StrategyStorage
 * @notice Storage helper for Aave V3 strategy configuration.
 */
library LibAaveV3StrategyStorage {
    bytes32 internal constant AAVE_V3_STRATEGY_STORAGE_POSITION = keccak256("diamondvault.aave.v3.strategy.storage");

    error LibAaveV3StrategyStorage__PoolAddressIsZero();
    error LibAaveV3StrategyStorage__ATokenAddressIsZero();
    error LibAaveV3StrategyStorage__StrategyNotConfigured(bytes32 strategyId);

    struct AaveV3StrategyConfig {
        address pool;
        address aToken;
    }

    struct AaveV3StrategyStorage {
        mapping(bytes32 => AaveV3StrategyConfig) strategies;
    }

    function aaveV3StrategyStorage() internal pure returns (AaveV3StrategyStorage storage avs) {
        bytes32 position = AAVE_V3_STRATEGY_STORAGE_POSITION;
        assembly {
            avs.slot := position
        }
    }

    function setConfig(bytes32 strategyId, address pool, address aToken)
        internal
        returns (address previousPool, address previousAToken)
    {
        if (pool == address(0)) revert LibAaveV3StrategyStorage__PoolAddressIsZero();
        if (aToken == address(0)) revert LibAaveV3StrategyStorage__ATokenAddressIsZero();

        AaveV3StrategyStorage storage avs = aaveV3StrategyStorage();
        previousPool = avs.strategies[strategyId].pool;
        previousAToken = avs.strategies[strategyId].aToken;
        avs.strategies[strategyId] = AaveV3StrategyConfig({pool: pool, aToken: aToken});
    }

    function configOf(bytes32 strategyId) internal view returns (AaveV3StrategyConfig memory config) {
        config = aaveV3StrategyStorage().strategies[strategyId];
        if (config.pool == address(0) || config.aToken == address(0)) {
            revert LibAaveV3StrategyStorage__StrategyNotConfigured(strategyId);
        }
    }
}
