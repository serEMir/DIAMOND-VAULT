// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/diamond/facets/OwnershipFacet.sol";
import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";
import {DiamondInit} from "../src/diamond/upgrade/DiamondInit.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {AaveV3StrategyFacet} from "../src/strategy/facets/AaveV3StrategyFacet.sol";
import {StrategyKeeperFacet} from "../src/strategy/facets/StrategyKeeperFacet.sol";
import {StrategyManagerFacet} from "../src/strategy/facets/StrategyManagerFacet.sol";
import {IAaveV3StrategyFacet} from "../src/strategy/interfaces/IAaveV3StrategyFacet.sol";
import {IStrategyKeeper} from "../src/strategy/interfaces/IStrategyKeeper.sol";
import {IStrategyManager} from "../src/strategy/interfaces/IStrategyManager.sol";
import {Vault4626Facet} from "../src/vault/facets/Vault4626Facet.sol";
import {VaultPauseFacet} from "../src/vault/facets/VaultPauseFacet.sol";
import {VaultShareFacet} from "../src/vault/facets/VaultShareFacet.sol";
import {IVaultPauseAdmin} from "../src/vault/interfaces/IVaultPauseAdmin.sol";
import {VaultInit} from "../src/vault/upgrade/VaultInit.sol";
import {DiamondVaultSelectors} from "./DiamondVaultSelectors.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

library DiamondVaultDeployment {
    struct Deployment {
        address diamond;
        address asset;
        address diamondCutFacet;
        address diamondLoupeFacet;
        address ownershipFacet;
        address vaultShareFacet;
        address vault4626Facet;
        address vaultPauseFacet;
        address strategyManagerFacet;
        address strategyKeeperFacet;
        address aaveV3StrategyFacet;
        address diamondInit;
        address vaultInit;
    }

    function deploy(HelperConfig.NetworkConfig memory config) internal returns (Deployment memory deployment) {
        deployment = _deployContracts(config);
        _installFacets(deployment);
        _initializeVault(deployment, config);
        _configureRoles(deployment, config);
        _configureAaveStrategy(deployment, config);
        _transferFinalOwnership(deployment, config);
    }

    function logDeployment(Deployment memory deployment, HelperConfig.NetworkConfig memory config) internal view {
        console2.log("Diamond Vault deployed");
        console2.log("deployer", config.deployer);
        console2.log("owner", IERC173(deployment.diamond).owner());
        console2.log("diamond", deployment.diamond);
        console2.log("asset", deployment.asset);
        console2.log("strategyKeeperFacet", deployment.strategyKeeperFacet);
        console2.log("aaveV3StrategyFacet", deployment.aaveV3StrategyFacet);

        if (config.keeper != address(0)) console2.log("keeper", config.keeper);
        if (config.guardian != address(0)) console2.log("guardian", config.guardian);
        if (config.registerAaveStrategy) {
            console2.log("aaveStrategyId");
            console2.logBytes32(config.aaveStrategyId);
            console2.log("aavePool", config.aavePool);
            console2.log("aaveAToken", config.aaveAToken);
            console2.log("aaveActive", config.activateAaveStrategy);
        }
    }

    function _deployContracts(HelperConfig.NetworkConfig memory config) private returns (Deployment memory deployment) {
        deployment.asset = config.asset == address(0) ? address(new MockUSDC()) : config.asset;
        deployment.diamondCutFacet = address(new DiamondCutFacet());
        deployment.diamond = address(new Diamond(config.deployer, deployment.diamondCutFacet));

        deployment.diamondLoupeFacet = address(new DiamondLoupeFacet());
        deployment.ownershipFacet = address(new OwnershipFacet());
        deployment.vaultShareFacet = address(new VaultShareFacet());
        deployment.vault4626Facet = address(new Vault4626Facet());
        deployment.vaultPauseFacet = address(new VaultPauseFacet());
        deployment.strategyManagerFacet = address(new StrategyManagerFacet());
        deployment.strategyKeeperFacet = address(new StrategyKeeperFacet());
        deployment.aaveV3StrategyFacet = address(new AaveV3StrategyFacet());
        deployment.diamondInit = address(new DiamondInit());
        deployment.vaultInit = address(new VaultInit());
    }

    function _installFacets(Deployment memory deployment) private {
        IDiamondCut(deployment.diamond)
            .diamondCut(
                DiamondVaultSelectors.initialCut(_facetAddresses(deployment)),
                deployment.diamondInit,
                abi.encodeWithSelector(DiamondInit.init.selector)
            );
    }

    function _initializeVault(Deployment memory deployment, HelperConfig.NetworkConfig memory config) private {
        IDiamondCut(deployment.diamond)
            .diamondCut(
                new IDiamondCut.FacetCut[](0),
                deployment.vaultInit,
                abi.encodeWithSelector(VaultInit.init.selector, deployment.asset, config.vaultName, config.vaultSymbol)
            );
    }

    function _configureRoles(Deployment memory deployment, HelperConfig.NetworkConfig memory config) private {
        if (config.guardian != address(0)) {
            IVaultPauseAdmin(deployment.diamond).setGuardian(config.guardian);
        }

        if (config.keeper != address(0)) {
            IStrategyKeeper(deployment.diamond).setKeeper(config.keeper);
        }
    }

    function _configureAaveStrategy(Deployment memory deployment, HelperConfig.NetworkConfig memory config) private {
        if (!config.registerAaveStrategy) return;

        IStrategyManager strategyManager = IStrategyManager(deployment.diamond);
        strategyManager.registerStrategy(
            config.aaveStrategyId,
            IAaveV3StrategyFacet.aaveV3StrategyDeploy.selector,
            IAaveV3StrategyFacet.aaveV3StrategyFreeFunds.selector,
            IAaveV3StrategyFacet.aaveV3StrategyHarvest.selector
        );

        IAaveV3StrategyFacet(deployment.diamond)
            .setAaveV3StrategyConfig(config.aaveStrategyId, config.aavePool, config.aaveAToken);

        if (config.activateAaveStrategy) {
            strategyManager.setStrategyActive(config.aaveStrategyId, true);
        }
    }

    function _transferFinalOwnership(Deployment memory deployment, HelperConfig.NetworkConfig memory config) private {
        if (config.finalOwner != config.deployer) {
            IERC173(deployment.diamond).transferOwnership(config.finalOwner);
        }
    }

    function _facetAddresses(Deployment memory deployment)
        private
        pure
        returns (DiamondVaultSelectors.FacetAddresses memory facets)
    {
        facets = DiamondVaultSelectors.FacetAddresses({
            diamondLoupeFacet: deployment.diamondLoupeFacet,
            ownershipFacet: deployment.ownershipFacet,
            vaultShareFacet: deployment.vaultShareFacet,
            vault4626Facet: deployment.vault4626Facet,
            vaultPauseFacet: deployment.vaultPauseFacet,
            strategyManagerFacet: deployment.strategyManagerFacet,
            strategyKeeperFacet: deployment.strategyKeeperFacet,
            aaveV3StrategyFacet: deployment.aaveV3StrategyFacet
        });
    }
}
