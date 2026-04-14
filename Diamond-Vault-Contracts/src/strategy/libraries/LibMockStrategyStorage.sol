// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibMockStrategyStorage
 * @notice Storage helper library for configuring mock strategy yield sources.
 */
library LibMockStrategyStorage {
    /**
     * @dev Storage slot used to locate the mock strategy configuration state.
     */
    bytes32 internal constant MOCK_STRATEGY_STORAGE_POSITION = keccak256("diamondvault.mock.strategy.storage");

    error LibMockStrategyStorage__SourceAddressIsZero();
    error LibMockStrategyStorage__StrategySourceNotConfigured(bytes32 strategyId);

    /**
     * @notice Configuration stored for a mock strategy.
     */
    struct MockStrategyConfig {
        address source;
    }

    /**
     * @notice Canonical storage layout for the mock strategy module.
     */
    struct MockStrategyStorage {
        mapping(bytes32 => MockStrategyConfig) strategies;
    }

    /**
     * @notice Returns the storage pointer for the mock strategy module.
     * @return mss The storage struct located at `MOCK_STRATEGY_STORAGE_POSITION`.
     */
    function mockStrategyStorage() internal pure returns (MockStrategyStorage storage mss) {
        bytes32 position = MOCK_STRATEGY_STORAGE_POSITION;
        assembly {
            mss.slot := position
        }
    }

    /**
     * @notice Sets the mock yield source for a strategy.
     * @param strategyId The strategy id to configure.
     * @param source The yield source contract to associate with the strategy.
     * @return previousSource The previously configured source address.
     */
    function setSource(bytes32 strategyId, address source) internal returns (address previousSource) {
        if (source == address(0)) revert LibMockStrategyStorage__SourceAddressIsZero();

        MockStrategyStorage storage mss = mockStrategyStorage();
        previousSource = mss.strategies[strategyId].source;
        mss.strategies[strategyId].source = source;
    }

    /**
     * @notice Returns the configured yield source for a strategy.
     * @param strategyId The strategy id to query.
     * @return source The configured yield source.
     */
    function sourceOf(bytes32 strategyId) internal view returns (address source) {
        source = mockStrategyStorage().strategies[strategyId].source;
        if (source == address(0)) revert LibMockStrategyStorage__StrategySourceNotConfigured(strategyId);
    }
}
