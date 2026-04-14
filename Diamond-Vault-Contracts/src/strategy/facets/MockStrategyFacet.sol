// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {MockYieldSource} from "../../mocks/MockYieldSource.sol";
import {IMockStrategyFacet} from "../interfaces/IMockStrategyFacet.sol";
import {LibMockStrategyStorage} from "../libraries/LibMockStrategyStorage.sol";
import {LibVaultStorage} from "../../vault/libraries/LibVaultStorage.sol";

/**
 * @title MockStrategyFacet
 * @notice Facet that simulates strategy actions against a configurable mock yield source.
 */
contract MockStrategyFacet is IMockStrategyFacet {
    using SafeERC20 for IERC20;

    error MockStrategyFacet__OnlyDiamond();

    /**
     * @notice Sets the mock yield source for a strategy.
     * @param strategyId The strategy id to configure.
     * @param source The yield source contract to associate with the strategy.
     */
    function setMockStrategySource(bytes32 strategyId, address source) external {
        LibDiamond.enforceIsContractOwner();
        address previousSource = LibMockStrategyStorage.setSource(strategyId, source);
        emit MockStrategySourceUpdated(strategyId, previousSource, source);
    }

    /**
     * @notice Returns the configured mock yield source for a strategy.
     * @param strategyId The strategy id to query.
     * @return source The configured yield source.
     */
    function mockStrategySource(bytes32 strategyId) external view returns (address source) {
        source = LibMockStrategyStorage.sourceOf(strategyId);
    }

    /**
     * @notice Deposits assets into the configured mock yield source.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount of assets to deploy.
     * @return deployedAssets The amount of assets reported as deployed.
     */
    function mockStrategyDeploy(bytes32 strategyId, uint256 assets) external returns (uint256 deployedAssets) {
        _enforceOnlyDiamond();

        address source = LibMockStrategyStorage.sourceOf(strategyId);
        IERC20 asset = IERC20(LibVaultStorage.vaultStorage().asset);
        asset.forceApprove(source, assets);
        MockYieldSource(source).deposit(assets);
        asset.forceApprove(source, 0);

        return assets;
    }

    /**
     * @notice Withdraws assets from the configured mock yield source.
     * @param strategyId The strategy id to operate on.
     * @param assets The amount of assets requested.
     * @return freedAssets The amount of assets actually returned.
     * @return loss The realized loss, if any.
     */
    function mockStrategyFreeFunds(bytes32 strategyId, uint256 assets)
        external
        returns (uint256 freedAssets, uint256 loss)
    {
        _enforceOnlyDiamond();

        address source = LibMockStrategyStorage.sourceOf(strategyId);
        freedAssets = MockYieldSource(source).withdraw(assets);
        loss = assets - freedAssets;
    }

    /**
     * @notice Returns the assets currently reported by the configured mock yield source.
     * @param strategyId The strategy id to query.
     * @return totalManagedAssets The assets reported for the diamond's position.
     */
    function mockStrategyHarvest(bytes32 strategyId) external view returns (uint256 totalManagedAssets) {
        _enforceOnlyDiamond();
        totalManagedAssets =
            MockYieldSource(LibMockStrategyStorage.sourceOf(strategyId)).reportedAssetsOf(address(this));
    }

    /**
     * @notice Reverts unless the call originated from the diamond itself.
     */
    function _enforceOnlyDiamond() private view {
        if (msg.sender != address(this)) revert MockStrategyFacet__OnlyDiamond();
    }
}
