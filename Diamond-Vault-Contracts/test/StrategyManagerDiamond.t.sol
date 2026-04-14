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
import {MockYieldSource} from "../src/mocks/MockYieldSource.sol";
import {VaultShareFacet} from "../src/vault/facets/VaultShareFacet.sol";
import {Vault4626Facet} from "../src/vault/facets/Vault4626Facet.sol";
import {VaultPauseFacet} from "../src/vault/facets/VaultPauseFacet.sol";
import {IVaultPauseAdmin} from "../src/vault/interfaces/IVaultPauseAdmin.sol";
import {LibReentrancyGuard} from "../src/vault/libraries/LibReentrancyGuard.sol";
import {LibVaultStorage} from "../src/vault/libraries/LibVaultStorage.sol";
import {VaultInit} from "../src/vault/upgrade/VaultInit.sol";
import {IStrategyManager} from "../src/strategy/interfaces/IStrategyManager.sol";
import {IMockStrategyFacet} from "../src/strategy/interfaces/IMockStrategyFacet.sol";
import {StrategyManagerFacet} from "../src/strategy/facets/StrategyManagerFacet.sol";
import {MockStrategyFacet} from "../src/strategy/facets/MockStrategyFacet.sol";
import {LibStrategyStorage} from "../src/strategy/libraries/LibStrategyStorage.sol";

contract StrategyManagerDiamondTest is Test {
    address private owner = address(0xA11CE);
    address private guardian = address(0xBEEF);
    address private alice = address(0xA11CEA);
    address private bob = address(0xB0B);
    address private charlie = address(0xCA11E);

    uint256 private constant ONE_USDC = 1e6;
    uint256 private constant ONE_SHARE = 1e18;
    bytes32 private constant MOCK_STRATEGY_ID = keccak256("mock-usdc-strategy");

    Diamond private diamond;
    MockUSDC private usdc;
    MockYieldSource private source;

    function setUp() external {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(cutFacet));
        usdc = new MockUSDC();
        source = new MockYieldSource(address(usdc));

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        DiamondInit diamondInit = new DiamondInit();
        VaultShareFacet shareFacet = new VaultShareFacet();
        Vault4626Facet vaultFacet = new Vault4626Facet();
        VaultPauseFacet pauseFacet = new VaultPauseFacet();
        StrategyManagerFacet strategyManagerFacet = new StrategyManagerFacet();
        MockStrategyFacet mockStrategyFacet = new MockStrategyFacet();
        VaultInit vaultInit = new VaultInit();

        vm.startPrank(owner);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](7);
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
            facetAddress: address(mockStrategyFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsMockStrategy()
        });

        IDiamondCut(address(diamond))
            .diamondCut(cut, address(diamondInit), abi.encodeWithSelector(DiamondInit.init.selector));
        IDiamondCut(address(diamond))
            .diamondCut(
                new IDiamondCut.FacetCut[](0),
                address(vaultInit),
                abi.encodeWithSelector(VaultInit.init.selector, address(usdc), "Diamond Vault Share", "DVS")
            );

        IMockStrategyFacet(address(diamond)).setMockStrategySource(MOCK_STRATEGY_ID, address(source));
        IStrategyManager(address(diamond))
            .registerStrategy(
                MOCK_STRATEGY_ID,
                IMockStrategyFacet.mockStrategyDeploy.selector,
                IMockStrategyFacet.mockStrategyFreeFunds.selector,
                IMockStrategyFacet.mockStrategyHarvest.selector
            );
        IStrategyManager(address(diamond)).setStrategyActive(MOCK_STRATEGY_ID, true);

        vm.stopPrank();

        usdc.mint(alice, 1_000 * ONE_USDC);

        vm.prank(alice);
        usdc.approve(address(diamond), type(uint256).max);
    }

    function test_allocateToStrategyMovesIdleAssetsIntoReportedDebt() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        uint256 deployedAssets = strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        (,,,, uint256 debt,,,) = strategyManager.strategyState(MOCK_STRATEGY_ID);

        assertEq(deployedAssets, 60 * ONE_USDC);
        assertEq(debt, 60 * ONE_USDC);
        assertEq(strategyManager.totalStrategyDebt(), 60 * ONE_USDC);
        assertEq(vault.totalAssets(), 100 * ONE_USDC);
        assertEq(usdc.balanceOf(address(diamond)), 40 * ONE_USDC);
        assertEq(usdc.balanceOf(address(source)), 60 * ONE_USDC);
        assertEq(source.reportedAssetsOf(address(diamond)), 60 * ONE_USDC);
    }

    function test_harvestedProfitRaisesTotalAssets() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        usdc.mint(address(source), 10 * ONE_USDC);
        source.setReportedAssets(address(diamond), 70 * ONE_USDC);

        vm.prank(owner);
        (uint256 reportedAssets, uint256 gain, uint256 loss) = strategyManager.harvestStrategy(MOCK_STRATEGY_ID);

        assertEq(reportedAssets, 70 * ONE_USDC);
        assertEq(gain, 10 * ONE_USDC);
        assertEq(loss, 0);
        assertEq(strategyManager.totalStrategyDebt(), 70 * ONE_USDC);
        assertEq(vault.totalAssets(), 110 * ONE_USDC);
        assertEq(vault.convertToAssets(shareToken.balanceOf(alice)), 110 * ONE_USDC);
    }

    function test_harvestedLossLowersTotalAssets() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        source.setReportedAssets(address(diamond), 50 * ONE_USDC);

        vm.prank(owner);
        (uint256 reportedAssets, uint256 gain, uint256 loss) = strategyManager.harvestStrategy(MOCK_STRATEGY_ID);

        assertEq(reportedAssets, 50 * ONE_USDC);
        assertEq(gain, 0);
        assertEq(loss, 10 * ONE_USDC);
        assertEq(strategyManager.totalStrategyDebt(), 50 * ONE_USDC);
        assertEq(vault.totalAssets(), 90 * ONE_USDC);
    }

    function test_withdrawUsesIdleAssetsBeforeFreeingStrategyFunds() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(alice);
        uint256 burnedShares = vault.withdraw(30 * ONE_USDC, alice, alice);

        (,,,, uint256 debt,,,) = strategyManager.strategyState(MOCK_STRATEGY_ID);

        assertEq(burnedShares, 30 * ONE_SHARE);
        assertEq(debt, 60 * ONE_USDC);
        assertEq(strategyManager.totalStrategyDebt(), 60 * ONE_USDC);
        assertEq(source.reportedAssetsOf(address(diamond)), 60 * ONE_USDC);
        assertEq(usdc.balanceOf(address(diamond)), 10 * ONE_USDC);
        assertEq(usdc.balanceOf(alice), 930 * ONE_USDC);
    }

    function test_redeemRealizesStrategyLossDuringFundFreeing() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        source.setReportedAssets(address(diamond), 50 * ONE_USDC);
        uint256 aliceShares = shareToken.balanceOf(alice);

        vm.prank(alice);
        uint256 assetsReturned = vault.redeem(aliceShares, alice, alice);

        assertEq(assetsReturned, 90 * ONE_USDC);
        assertEq(strategyManager.totalStrategyDebt(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(shareToken.totalSupply(), 0);
        assertEq(usdc.balanceOf(alice), 990 * ONE_USDC);
    }

    function test_withdrawRevertsWhenRealizedLossLeavesInsufficientLiquidity() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        source.setReportedAssets(address(diamond), 50 * ONE_USDC);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(95 * ONE_USDC, alice, alice);

        assertEq(strategyManager.totalStrategyDebt(), 60 * ONE_USDC);
        assertEq(source.reportedAssetsOf(address(diamond)), 50 * ONE_USDC);
        assertEq(usdc.balanceOf(alice), 900 * ONE_USDC);
        assertEq(vault.totalAssets(), 100 * ONE_USDC);
    }

    function test_guardianCanPauseOrFreezeStrategyButCannotClearControls() external {
        IStrategyManager strategyManager = IStrategyManager(address(diamond));
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(owner);
        pauseAdmin.setGuardian(guardian);

        vm.prank(guardian);
        strategyManager.setStrategyAllocationsPaused(MOCK_STRATEGY_ID, true);

        vm.prank(guardian);
        strategyManager.setStrategyFrozen(MOCK_STRATEGY_ID, true);

        (,, bool allocationsPaused, bool frozen,,,,) = strategyManager.strategyState(MOCK_STRATEGY_ID);
        assertTrue(allocationsPaused);
        assertTrue(frozen);

        vm.prank(guardian);
        vm.expectRevert();
        strategyManager.setStrategyAllocationsPaused(MOCK_STRATEGY_ID, false);

        vm.prank(guardian);
        vm.expectRevert();
        strategyManager.setStrategyFrozen(MOCK_STRATEGY_ID, false);
    }

    function test_strategyAllocationPauseBlocksNewDeployment() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.setStrategyAllocationsPaused(MOCK_STRATEGY_ID, true);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibStrategyStorage.LibStrategyStorage__StrategyAllocationsPaused.selector, MOCK_STRATEGY_ID
            )
        );
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);
    }

    function test_frozenStrategyIsSkippedDuringAutomaticWithdrawLiquidityPrep() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(owner);
        strategyManager.setStrategyFrozen(MOCK_STRATEGY_ID, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibStrategyStorage.LibStrategyStorage__InsufficientLiquidity.selector, 50 * ONE_USDC, 40 * ONE_USDC
            )
        );
        vault.withdraw(50 * ONE_USDC, alice, alice);
    }

    function test_ownerCanManuallyFreeFundsFromFrozenStrategy() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(owner);
        strategyManager.setStrategyFrozen(MOCK_STRATEGY_ID, true);

        vm.prank(owner);
        (uint256 freedAssets, uint256 loss) = strategyManager.freeFundsFromStrategy(MOCK_STRATEGY_ID, 20 * ONE_USDC);

        (,,,, uint256 debt,,,) = strategyManager.strategyState(MOCK_STRATEGY_ID);

        assertEq(freedAssets, 20 * ONE_USDC);
        assertEq(loss, 0);
        assertEq(debt, 40 * ONE_USDC);
        assertEq(usdc.balanceOf(address(diamond)), 60 * ONE_USDC);
        assertEq(usdc.balanceOf(address(source)), 40 * ONE_USDC);
    }

    function test_frozenStrategyBlocksHarvest() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(owner);
        strategyManager.setStrategyFrozen(MOCK_STRATEGY_ID, true);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(LibStrategyStorage.LibStrategyStorage__StrategyFrozen.selector, MOCK_STRATEGY_ID)
        );
        strategyManager.harvestStrategy(MOCK_STRATEGY_ID);
    }

    function test_withdrawFailsEarlyWhenOwnerCannotCoverEvenBestCaseShares() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));
        IMockStrategyFacet mockStrategy = IMockStrategyFacet(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        AlwaysRevertingYieldSource revertingSource = new AlwaysRevertingYieldSource();

        vm.prank(owner);
        mockStrategy.setMockStrategySource(MOCK_STRATEGY_ID, address(revertingSource));

        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibVaultStorage.LibVaultStorage__InsufficientBalance.selector, charlie, 0, 50 * ONE_SHARE
            )
        );
        vault.withdraw(50 * ONE_USDC, charlie, charlie);
    }

    function test_redeemFailsEarlyWhenCallerLacksAllowance() external {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));
        IMockStrategyFacet mockStrategy = IMockStrategyFacet(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        AlwaysRevertingYieldSource revertingSource = new AlwaysRevertingYieldSource();

        vm.prank(owner);
        mockStrategy.setMockStrategySource(MOCK_STRATEGY_ID, address(revertingSource));

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibVaultStorage.LibVaultStorage__InsufficientAllowance.selector, alice, bob, 0, 50 * ONE_SHARE
            )
        );
        vault.redeem(50 * ONE_SHARE, bob, alice);
    }

    function test_withdrawBlocksStrategyReentrancy() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));
        IMockStrategyFacet mockStrategy = IMockStrategyFacet(address(diamond));

        ReentrantYieldSource reentrantSource =
            new ReentrantYieldSource(address(usdc), address(diamond), alice, alice, ONE_SHARE);

        vm.prank(owner);
        mockStrategy.setMockStrategySource(MOCK_STRATEGY_ID, address(reentrantSource));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(alice);
        shareToken.approve(address(reentrantSource), type(uint256).max);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);

        vm.prank(alice);
        uint256 burnedShares = vault.withdraw(50 * ONE_USDC, alice, alice);

        assertEq(burnedShares, 50 * ONE_SHARE);
        assertTrue(reentrantSource.reentryAttempted());
        assertTrue(reentrantSource.reentryBlocked());
        assertEq(reentrantSource.lastErrorSelector(), LibReentrancyGuard.LibReentrancyGuard__ReentrantCall.selector);
        assertEq(usdc.balanceOf(alice), 950 * ONE_USDC);
    }

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

    function _selectorsMockStrategy() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IMockStrategyFacet.setMockStrategySource.selector;
        selectors[1] = IMockStrategyFacet.mockStrategySource.selector;
        selectors[2] = IMockStrategyFacet.mockStrategyDeploy.selector;
        selectors[3] = IMockStrategyFacet.mockStrategyFreeFunds.selector;
        selectors[4] = IMockStrategyFacet.mockStrategyHarvest.selector;
    }
}

contract AlwaysRevertingYieldSource {
    error AlwaysRevertingYieldSource__UnexpectedWithdraw();

    function reportedAssetsOf(address) external pure returns (uint256) {
        return 0;
    }

    function deposit(uint256) external pure {}

    function withdraw(uint256) external pure returns (uint256) {
        revert AlwaysRevertingYieldSource__UnexpectedWithdraw();
    }
}

contract ReentrantYieldSource {
    IERC20 public immutable asset;
    IERC4626 public immutable vault;
    address public immutable owner;
    address public immutable receiver;
    uint256 public immutable reentryShares;

    bool public reentryAttempted;
    bool public reentryBlocked;
    bytes4 public lastErrorSelector;

    mapping(address => uint256) public reportedAssets;

    constructor(address asset_, address vault_, address owner_, address receiver_, uint256 reentryShares_) {
        asset = IERC20(asset_);
        vault = IERC4626(vault_);
        owner = owner_;
        receiver = receiver_;
        reentryShares = reentryShares_;
    }

    function reportedAssetsOf(address account) external view returns (uint256 assets_) {
        assets_ = reportedAssets[account];
    }

    function deposit(uint256 assets_) external {
        asset.transferFrom(msg.sender, address(this), assets_);
        reportedAssets[msg.sender] += assets_;
    }

    function withdraw(uint256 assets_) external returns (uint256 withdrawnAssets) {
        if (!reentryAttempted) {
            reentryAttempted = true;

            try vault.redeem(reentryShares, receiver, owner) {}
            catch (bytes memory err) {
                if (err.length >= 4) {
                    bytes4 selector;
                    assembly {
                        selector := mload(add(err, 32))
                    }
                    lastErrorSelector = selector;
                }
                reentryBlocked = true;
            }
        }

        uint256 position = reportedAssets[msg.sender];
        withdrawnAssets = assets_;
        if (withdrawnAssets > position) {
            withdrawnAssets = position;
        }

        reportedAssets[msg.sender] = position - withdrawnAssets;
        if (withdrawnAssets != 0) {
            asset.transfer(msg.sender, withdrawnAssets);
        }
    }
}
