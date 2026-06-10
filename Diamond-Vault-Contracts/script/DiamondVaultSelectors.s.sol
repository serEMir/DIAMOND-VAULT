// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";
import {IAaveV3StrategyFacet} from "../src/strategy/interfaces/IAaveV3StrategyFacet.sol";
import {IStrategyKeeper} from "../src/strategy/interfaces/IStrategyKeeper.sol";
import {IStrategyManager} from "../src/strategy/interfaces/IStrategyManager.sol";
import {IVaultPauseAdmin} from "../src/vault/interfaces/IVaultPauseAdmin.sol";

library DiamondVaultSelectors {
    struct FacetAddresses {
        address diamondLoupeFacet;
        address ownershipFacet;
        address vaultShareFacet;
        address vault4626Facet;
        address vaultPauseFacet;
        address strategyManagerFacet;
        address strategyKeeperFacet;
        address aaveV3StrategyFacet;
    }

    function initialCut(FacetAddresses memory facets) internal pure returns (IDiamondCut.FacetCut[] memory cut) {
        cut = new IDiamondCut.FacetCut[](8);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: facets.diamondLoupeFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: loupe()
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: facets.ownershipFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: ownership()
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: facets.vaultShareFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: share()
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: facets.vault4626Facet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: vault()
        });
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: facets.vaultPauseFacet, action: IDiamondCut.FacetCutAction.Add, functionSelectors: pause()
        });
        cut[5] = IDiamondCut.FacetCut({
            facetAddress: facets.strategyManagerFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: strategyManager()
        });
        cut[6] = IDiamondCut.FacetCut({
            facetAddress: facets.strategyKeeperFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: strategyKeeper()
        });
        cut[7] = IDiamondCut.FacetCut({
            facetAddress: facets.aaveV3StrategyFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: aaveStrategy()
        });
    }

    function loupe() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = bytes4(keccak256("supportsInterface(bytes4)"));
    }

    function ownership() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
    }

    function share() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](9);
        selectors[0] = IERC20Metadata.name.selector;
        selectors[1] = IERC20Metadata.symbol.selector;
        selectors[2] = IERC20Metadata.decimals.selector;
        selectors[3] = IERC20.totalSupply.selector;
        selectors[4] = IERC20.balanceOf.selector;
        selectors[5] = IERC20.transfer.selector;
        selectors[6] = IERC20.allowance.selector;
        selectors[7] = IERC20.approve.selector;
        selectors[8] = IERC20.transferFrom.selector;
    }

    function vault() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](16);
        selectors[0] = IERC4626.asset.selector;
        selectors[1] = IERC4626.totalAssets.selector;
        selectors[2] = IERC4626.convertToShares.selector;
        selectors[3] = IERC4626.convertToAssets.selector;
        selectors[4] = IERC4626.maxDeposit.selector;
        selectors[5] = IERC4626.previewDeposit.selector;
        selectors[6] = IERC4626.deposit.selector;
        selectors[7] = IERC4626.maxMint.selector;
        selectors[8] = IERC4626.previewMint.selector;
        selectors[9] = IERC4626.mint.selector;
        selectors[10] = IERC4626.maxWithdraw.selector;
        selectors[11] = IERC4626.previewWithdraw.selector;
        selectors[12] = IERC4626.withdraw.selector;
        selectors[13] = IERC4626.maxRedeem.selector;
        selectors[14] = IERC4626.previewRedeem.selector;
        selectors[15] = IERC4626.redeem.selector;
    }

    function pause() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](9);
        selectors[0] = IVaultPauseAdmin.guardian.selector;
        selectors[1] = IVaultPauseAdmin.depositsPaused.selector;
        selectors[2] = IVaultPauseAdmin.withdrawalsPaused.selector;
        selectors[3] = IVaultPauseAdmin.shareTransfersPaused.selector;
        selectors[4] = IVaultPauseAdmin.pauseState.selector;
        selectors[5] = IVaultPauseAdmin.setGuardian.selector;
        selectors[6] = IVaultPauseAdmin.setDepositsPaused.selector;
        selectors[7] = IVaultPauseAdmin.setWithdrawalsPaused.selector;
        selectors[8] = IVaultPauseAdmin.setShareTransfersPaused.selector;
    }

    function strategyManager() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](10);
        selectors[0] = IStrategyManager.strategyIds.selector;
        selectors[1] = IStrategyManager.totalStrategyDebt.selector;
        selectors[2] = IStrategyManager.strategyState.selector;
        selectors[3] = IStrategyManager.registerStrategy.selector;
        selectors[4] = IStrategyManager.setStrategyActive.selector;
        selectors[5] = IStrategyManager.setStrategyAllocationsPaused.selector;
        selectors[6] = IStrategyManager.setStrategyFrozen.selector;
        selectors[7] = IStrategyManager.allocateToStrategy.selector;
        selectors[8] = IStrategyManager.freeFundsFromStrategy.selector;
        selectors[9] = IStrategyManager.harvestStrategy.selector;
    }

    function strategyKeeper() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3);
        selectors[0] = IStrategyKeeper.keeper.selector;
        selectors[1] = IStrategyKeeper.setKeeper.selector;
        selectors[2] = IStrategyKeeper.keeperHarvestStrategy.selector;
    }

    function aaveStrategy() internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IAaveV3StrategyFacet.setAaveV3StrategyConfig.selector;
        selectors[1] = IAaveV3StrategyFacet.aaveV3StrategyConfig.selector;
        selectors[2] = IAaveV3StrategyFacet.aaveV3StrategyDeploy.selector;
        selectors[3] = IAaveV3StrategyFacet.aaveV3StrategyFreeFunds.selector;
        selectors[4] = IAaveV3StrategyFacet.aaveV3StrategyHarvest.selector;
    }
}
