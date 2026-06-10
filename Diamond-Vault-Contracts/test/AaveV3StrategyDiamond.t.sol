// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Test} from "forge-std/Test.sol";

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/diamond/facets/OwnershipFacet.sol";
import {DiamondInit} from "../src/diamond/upgrade/DiamondInit.sol";
import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockAavePool} from "../src/mocks/MockAavePool.sol";
import {MockAToken} from "../src/mocks/MockAToken.sol";
import {VaultShareFacet} from "../src/vault/facets/VaultShareFacet.sol";
import {Vault4626Facet} from "../src/vault/facets/Vault4626Facet.sol";
import {VaultPauseFacet} from "../src/vault/facets/VaultPauseFacet.sol";
import {IVaultPauseAdmin} from "../src/vault/interfaces/IVaultPauseAdmin.sol";
import {VaultInit} from "../src/vault/upgrade/VaultInit.sol";
import {IStrategyManager} from "../src/strategy/interfaces/IStrategyManager.sol";
import {IStrategyKeeper} from "../src/strategy/interfaces/IStrategyKeeper.sol";
import {IAaveV3StrategyFacet} from "../src/strategy/interfaces/IAaveV3StrategyFacet.sol";
import {StrategyManagerFacet} from "../src/strategy/facets/StrategyManagerFacet.sol";
import {StrategyKeeperFacet} from "../src/strategy/facets/StrategyKeeperFacet.sol";
import {AaveV3StrategyFacet} from "../src/strategy/facets/AaveV3StrategyFacet.sol";

contract AaveV3StrategyDiamondTest is Test {
    address private owner = address(0xA11CE);
    address private alice = address(0xA11CEA);
    address private keeper = address(0xC0FFEE);

    uint256 private constant ONE_USDC = 1e6;
    uint256 private constant ONE_SHARE = 1e18;
    bytes32 private constant AAVE_STRATEGY_ID = keccak256("aave-v3-usdc-strategy");

    Diamond private diamond;
    MockUSDC private usdc;
    MockAavePool private pool;
    MockAToken private aToken;

    // =======================================================================
    // Setup
    // =======================================================================
    function setUp() external {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(cutFacet));
        usdc = new MockUSDC();
        pool = new MockAavePool(address(usdc));
        aToken = pool.aToken();

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        DiamondInit diamondInit = new DiamondInit();
        VaultShareFacet shareFacet = new VaultShareFacet();
        Vault4626Facet vaultFacet = new Vault4626Facet();
        VaultPauseFacet pauseFacet = new VaultPauseFacet();
        StrategyManagerFacet strategyManagerFacet = new StrategyManagerFacet();
        StrategyKeeperFacet strategyKeeperFacet = new StrategyKeeperFacet();
        AaveV3StrategyFacet aaveStrategyFacet = new AaveV3StrategyFacet();
        VaultInit vaultInit = new VaultInit();

        vm.startPrank(owner);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](8);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsLoupe()
        });
        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsOwnership()
        });
        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(shareFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsShare()
        });
        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(vaultFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsVault()
        });
        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(pauseFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsPause()
        });
        cut[5] = IDiamondCut.FacetCut({
            facetAddress: address(strategyManagerFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsStrategyManager()
        });
        cut[6] = IDiamondCut.FacetCut({
            facetAddress: address(aaveStrategyFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsAaveStrategy()
        });
        cut[7] = IDiamondCut.FacetCut({
            facetAddress: address(strategyKeeperFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsStrategyKeeper()
        });

        IDiamondCut(address(diamond))
            .diamondCut(cut, address(diamondInit), abi.encodeWithSelector(DiamondInit.init.selector));
        IDiamondCut(address(diamond))
            .diamondCut(
                new IDiamondCut.FacetCut[](0),
                address(vaultInit),
                abi.encodeWithSelector(VaultInit.init.selector, address(usdc), "Diamond Vault Share", "DVS")
            );

        IStrategyManager(address(diamond))
            .registerStrategy(
                AAVE_STRATEGY_ID,
                IAaveV3StrategyFacet.aaveV3StrategyDeploy.selector,
                IAaveV3StrategyFacet.aaveV3StrategyFreeFunds.selector,
                IAaveV3StrategyFacet.aaveV3StrategyHarvest.selector
            );

        IAaveV3StrategyFacet(address(diamond)).setAaveV3StrategyConfig(AAVE_STRATEGY_ID, address(pool), address(aToken));

        IStrategyManager(address(diamond)).setStrategyActive(AAVE_STRATEGY_ID, true);

        vm.stopPrank();

        usdc.mint(alice, 1_000 * ONE_USDC);
        vm.prank(alice);
        usdc.approve(address(diamond), type(uint256).max);
    }

    // =============================================================================
    // Tests
    // =============================================================================

    function test_allocateToAaveSuppliesUnderlyingAndTracksDebt() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        uint256 deployedAssets = strategyManager.allocateToStrategy(AAVE_STRATEGY_ID, 60 * ONE_USDC);

        (,,,, uint256 debt,,,) = strategyManager.strategyState(AAVE_STRATEGY_ID);

        assertEq(deployedAssets, 60 * ONE_USDC);
        assertEq(debt, 60 * ONE_USDC);
        assertEq(strategyManager.totalStrategyDebt(), 60 * ONE_USDC);
        assertEq(vault.totalAssets(), 100 * ONE_USDC);
        assertEq(usdc.balanceOf(address(diamond)), 40 * ONE_USDC);
        assertEq(usdc.balanceOf(address(pool)), 60 * ONE_USDC);
        assertEq(aToken.balanceOf(address(diamond)), 60 * ONE_USDC);
    }

    function test_harvestOnAaveRecognizesAccruedYield() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(AAVE_STRATEGY_ID, 60 * ONE_USDC);

        pool.accrueYield(address(diamond), 10 * ONE_USDC);

        vm.prank(owner);
        (uint256 reportedAssets, uint256 gain, uint256 loss) = strategyManager.harvestStrategy(AAVE_STRATEGY_ID);

        assertEq(reportedAssets, 70 * ONE_USDC);
        assertEq(gain, 10 * ONE_USDC);
        assertEq(loss, 0);
        assertEq(strategyManager.totalStrategyDebt(), 70 * ONE_USDC);
        assertEq(vault.totalAssets(), 110 * ONE_USDC);
        assertEq(vault.convertToAssets(shareToken.balanceOf(alice)), 110 * ONE_USDC);
    }

    function test_keeperCanHarvestAaveStrategy() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));
        IStrategyKeeper strategyKeeper = IStrategyKeeper(address(diamond));

        vm.prank(owner);
        strategyKeeper.setKeeper(keeper);

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(AAVE_STRATEGY_ID, 60 * ONE_USDC);

        pool.accrueYield(address(diamond), 10 * ONE_USDC);

        vm.prank(keeper);
        (uint256 reportedAssets, uint256 gain, uint256 loss) = strategyKeeper.keeperHarvestStrategy(AAVE_STRATEGY_ID);

        assertEq(reportedAssets, 70 * ONE_USDC);
        assertEq(gain, 10 * ONE_USDC);
        assertEq(loss, 0);
        assertEq(strategyManager.totalStrategyDebt(), 70 * ONE_USDC);
        assertEq(vault.totalAssets(), 110 * ONE_USDC);
    }

    function test_keeperCannotChangeAaveConfig() external {
        IStrategyKeeper strategyKeeper = IStrategyKeeper(address(diamond));

        vm.prank(owner);
        strategyKeeper.setKeeper(keeper);

        vm.prank(keeper);
        vm.expectRevert();
        IAaveV3StrategyFacet(address(diamond)).setAaveV3StrategyConfig(AAVE_STRATEGY_ID, address(pool), address(aToken));
    }

    function test_manualFreeFundsPullsUnderlyingBackFromAave() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(AAVE_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(owner);
        (uint256 freedAssets, uint256 loss) = strategyManager.freeFundsFromStrategy(AAVE_STRATEGY_ID, 20 * ONE_USDC);

        (,,,, uint256 debt,,,) = strategyManager.strategyState(AAVE_STRATEGY_ID);

        assertEq(freedAssets, 20 * ONE_USDC);
        assertEq(loss, 0);
        assertEq(debt, 40 * ONE_USDC);
        assertEq(usdc.balanceOf(address(diamond)), 60 * ONE_USDC);
        assertEq(usdc.balanceOf(address(pool)), 40 * ONE_USDC);
        assertEq(aToken.balanceOf(address(diamond)), 40 * ONE_USDC);
        assertEq(vault.totalAssets(), 100 * ONE_USDC);
    }

    function test_withdrawPullsFromAaveWhenIdleCashIsNotEnough() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(AAVE_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(alice);
        uint256 burnedShares = vault.withdraw(50 * ONE_USDC, alice, alice);

        (,,,, uint256 debt,,,) = strategyManager.strategyState(AAVE_STRATEGY_ID);

        assertEq(burnedShares, 50 * ONE_SHARE);
        assertEq(debt, 50 * ONE_USDC);
        assertEq(strategyManager.totalStrategyDebt(), 50 * ONE_USDC);
        assertEq(usdc.balanceOf(address(diamond)), 0);
        assertEq(usdc.balanceOf(address(pool)), 50 * ONE_USDC);
        assertEq(aToken.balanceOf(address(diamond)), 50 * ONE_USDC);
        assertEq(usdc.balanceOf(alice), 950 * ONE_USDC);
    }

    function test_setAaveConfigRevertsWhenStrategyIsNotRegistered() external {
        bytes32 unregisteredId = keccak256("unregistered-aave-strategy");

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AaveV3StrategyFacet.AaveV3StrategyFacet__StrategyNotRegistered.selector, unregisteredId
            )
        );

        IAaveV3StrategyFacet(address(diamond)).setAaveV3StrategyConfig(unregisteredId, address(pool), address(aToken));
    }

    function test__setAaveConfigRevertsWhenPoolHasNoCode() external {
        address invalidPool = address(0xBEEF);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(AaveV3StrategyFacet.AaveV3StrategyFacet__PoolHasNoCode.selector, invalidPool)
        );
        IAaveV3StrategyFacet(address(diamond)).setAaveV3StrategyConfig(AAVE_STRATEGY_ID, invalidPool, address(aToken));
    }

    function test__setAaveConfigRevertsWhenATokenHasNoCode() external {
        address invalidAToken = address(0xBEEF);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(AaveV3StrategyFacet.AaveV3StrategyFacet__ATokenHasNoCode.selector, invalidAToken)
        );
        IAaveV3StrategyFacet(address(diamond)).setAaveV3StrategyConfig(AAVE_STRATEGY_ID, address(pool), invalidAToken);
    }

    function test__setAaveConfigRevertsWhenATokenUnderlyingMismatch() external {
        MockUSDC wrongUnderlying = new MockUSDC();
        MockAavePool wrongPool = new MockAavePool(address(wrongUnderlying));
        MockAToken wrongAToken = wrongPool.aToken();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AaveV3StrategyFacet.AaveV3StrategyFacet__ATokenUnderlyingMismatch.selector,
                AAVE_STRATEGY_ID,
                address(usdc),
                address(wrongUnderlying)
            )
        );
        IAaveV3StrategyFacet(address(diamond))
            .setAaveV3StrategyConfig(AAVE_STRATEGY_ID, address(pool), address(wrongAToken));
    }

    function test_setAaveConfigRevertsWhenATokenPoolDoesNotMatchConfiguredPool() external {
        MockAavePool otherPool = new MockAavePool(address(usdc));
        MockAToken otherAToken = otherPool.aToken();

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AaveV3StrategyFacet.AaveV3StrategyFacet__ATokenPoolMismatch.selector,
                AAVE_STRATEGY_ID,
                address(pool),
                address(otherPool)
            )
        );
        IAaveV3StrategyFacet(address(diamond))
            .setAaveV3StrategyConfig(AAVE_STRATEGY_ID, address(pool), address(otherAToken));
    }

    function test_setAaveConfigRevertsWhenStrateyDebtisNonZero() external {
        IERC4626 vault = IERC4626(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        IStrategyManager(address(diamond)).allocateToStrategy(AAVE_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AaveV3StrategyFacet.AaveV3StrategyFacet__StrategyConfigLocked.selector,
                AAVE_STRATEGY_ID,
                60 * ONE_USDC,
                60 * ONE_USDC
            )
        );
        IAaveV3StrategyFacet(address(diamond)).setAaveV3StrategyConfig(AAVE_STRATEGY_ID, address(pool), address(aToken));
    }

    function test_setAaveConfigRevertsWhenATokenBalanceIsNonZeroEvenIfDebtIsZero() external {
        pool.accrueYield(address(diamond), 1);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                AaveV3StrategyFacet.AaveV3StrategyFacet__StrategyConfigLocked.selector, AAVE_STRATEGY_ID, 0, 1
            )
        );
        IAaveV3StrategyFacet(address(diamond)).setAaveV3StrategyConfig(AAVE_STRATEGY_ID, address(pool), address(aToken));
    }

    function test_manualFreeFundsReturnPartialAmountWithoutReportingLoss() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(AAVE_STRATEGY_ID, 60 * ONE_USDC);

        // Leave only 5 usdc liquid in the mock pool.
        pool.drainLiquidity(address(0xBEEF), 55 * ONE_USDC);

        vm.prank(owner);
        (uint256 freedAssets, uint256 loss) = strategyManager.freeFundsFromStrategy(AAVE_STRATEGY_ID, 20 * ONE_USDC);

        (,,,, uint256 debt,,,) = strategyManager.strategyState(AAVE_STRATEGY_ID);

        assertEq(freedAssets, 5 * ONE_USDC);
        assertEq(loss, 0);

        // Debt should only decrease by what actually came back.
        assertEq(debt, 55 * ONE_USDC);
        assertEq(strategyManager.totalStrategyDebt(), 55 * ONE_USDC);
        assertEq(usdc.balanceOf(address(diamond)), 45 * ONE_USDC);
        assertEq(usdc.balanceOf(address(pool)), 0);
        assertEq(aToken.balanceOf(address(diamond)), 55 * ONE_USDC);

        // Total assets now reflects the drianed liquidity loss still sitting in the strategy as debt, but the vault shouldn't report a loss since the manager couldn't have done anything about the liquidity shortage.
        assertEq(vault.totalAssets(), 100 * ONE_USDC);
    }

    function test_externalCallerCannotInvokeAaveStrategyExecutionFunctions() external {
        IAaveV3StrategyFacet aaveStrategyFacet = IAaveV3StrategyFacet(address(diamond));

        vm.startPrank(alice);
        vm.expectRevert(AaveV3StrategyFacet.AaveV3StrategyFacet__OnlyDiamond.selector);
        aaveStrategyFacet.aaveV3StrategyDeploy(AAVE_STRATEGY_ID, 10 * ONE_USDC);

        vm.expectRevert(AaveV3StrategyFacet.AaveV3StrategyFacet__OnlyDiamond.selector);
        aaveStrategyFacet.aaveV3StrategyFreeFunds(AAVE_STRATEGY_ID, 10 * ONE_USDC);

        vm.expectRevert(AaveV3StrategyFacet.AaveV3StrategyFacet__OnlyDiamond.selector);
        aaveStrategyFacet.aaveV3StrategyHarvest(AAVE_STRATEGY_ID);

        vm.stopPrank();
    }

    // =============================================================================
    // Facet Selectors
    // =============================================================================

    function _selectorsLoupe() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = bytes4(keccak256("supportsInterface(bytes4)"));
    }

    function _selectorsOwnership() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
    }

    function _selectorsShare() private pure returns (bytes4[] memory selectors) {
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

    function _selectorsVault() private pure returns (bytes4[] memory selectors) {
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

    function _selectorsPause() private pure returns (bytes4[] memory selectors) {
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

    function _selectorsStrategyManager() private pure returns (bytes4[] memory selectors) {
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

    function _selectorsStrategyKeeper() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3);
        selectors[0] = IStrategyKeeper.keeper.selector;
        selectors[1] = IStrategyKeeper.setKeeper.selector;
        selectors[2] = IStrategyKeeper.keeperHarvestStrategy.selector;
    }

    function _selectorsAaveStrategy() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IAaveV3StrategyFacet.setAaveV3StrategyConfig.selector;
        selectors[1] = IAaveV3StrategyFacet.aaveV3StrategyConfig.selector;
        selectors[2] = IAaveV3StrategyFacet.aaveV3StrategyDeploy.selector;
        selectors[3] = IAaveV3StrategyFacet.aaveV3StrategyFreeFunds.selector;
        selectors[4] = IAaveV3StrategyFacet.aaveV3StrategyHarvest.selector;
    }
}
