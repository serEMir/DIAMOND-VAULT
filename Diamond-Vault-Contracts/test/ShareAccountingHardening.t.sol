// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
import {Diamond} from "../src/diamond/Diamond.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/diamond/facets/OwnershipFacet.sol";
import {Vault4626Facet} from "../src/vault/facets/Vault4626Facet.sol";
import {VaultShareFacet} from "../src/vault/facets/VaultShareFacet.sol";
import {VaultPauseFacet} from "../src/vault/facets/VaultPauseFacet.sol";
import {IVaultPauseAdmin} from "../src/vault/interfaces/IVaultPauseAdmin.sol";
import {VaultInit} from "../src/vault/upgrade/VaultInit.sol";

import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/diamond/interfaces/IDiamondLoupe.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";

contract ShareAccountingHardening is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    Diamond public diamond;
    DiamondCutFacet public cutFacet;
    DiamondLoupeFacet public loupeFacet;
    OwnershipFacet public ownershipFacet;
    Vault4626Facet public vaultFacet;
    VaultShareFacet public shareFacet;
    VaultPauseFacet public pauseFacet;
    // DiamondInit public diamondInit;

    MockUSDC public mockUsdc;
    uint256 public constant MINT_AMOUNT = 10_000e6;
    uint256 public constant DEPOSIT_AMOUNT = 1_000e6;
    uint256 public constant SHARE_DECIMALS = 1e18;
    uint256 public constant ASSET_DECIMALS = 1e6;

    // ============================================================================
    // Test Users
    // ============================================================================
    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    // ============================================================================
    // Setup and Initialization
    // ============================================================================

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mocks and facets
        mockUsdc = new MockUSDC();
        cutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(cutFacet));

        loupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        vaultFacet = new Vault4626Facet();
        shareFacet = new VaultShareFacet();
        pauseFacet = new VaultPauseFacet();

        //diamondInit = new DiamondInit();

        // Add facets to diamond
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);

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
            facetAddress: address(vaultFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsVault()
        });

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(shareFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsShare()
        });

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(pauseFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorPause()
        });

        VaultInit vaultInit = new VaultInit();
        IDiamondCut(address(diamond))
            .diamondCut(
                cut, address(vaultInit), abi.encodeCall(VaultInit.init, (address(mockUsdc), "Diamond Vault", "DVT"))
            );
        vm.stopPrank();

        mockUsdc.mint(alice, MINT_AMOUNT);
        mockUsdc.mint(bob, MINT_AMOUNT);
        mockUsdc.mint(charlie, MINT_AMOUNT);

        vm.startPrank(alice);
        mockUsdc.approve(address(diamond), MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(bob);
        mockUsdc.approve(address(diamond), MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(charlie);
        mockUsdc.approve(address(diamond), MINT_AMOUNT);
        vm.stopPrank();
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    function _simulateYield(uint256 yieldAmount) internal {
        mockUsdc.mint(address(diamond), yieldAmount);
    }

    function _getPricePerShare() internal view returns (uint256) {
        IERC4626 vault = IERC4626(address(diamond));
        uint256 totalAssets = vault.totalAssets();
        uint256 totalSupply = IERC20(address(diamond)).totalSupply();

        if (totalSupply == 0) return 0;
        return (totalAssets * SHARE_DECIMALS) / totalSupply;
    }

    function _logVaultState(string memory label) internal view {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shares = IERC20(address(diamond));
        console.log("=== VAULT STATE:", label, "===");
        console.log("Total Assets:", vault.totalAssets());
        console.log("Total Shares:", shares.totalSupply());
        console.log("Price Per Share:", _getPricePerShare());
    }

    // ============================================================================
    // TEST 1: ROUND-TRIP (DEPOSIT → REDEEM)
    // ============================================================================

    function test_depositThenRedeemReturnsApproximateAssets() external {
        _logVaultState("Initial State");
        vm.startPrank(alice);

        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shares = IERC20(address(diamond));
        uint256 sharesPurchased = vault.deposit(DEPOSIT_AMOUNT, alice);
        // uint256 sharesPurchased = vaultFacet.deposit(DEPOSIT_AMOUNT, alice);
        _logVaultState("After Deposit");
        uint256 assetsRedeemed = vault.redeem(sharesPurchased, alice, alice);
        _logVaultState("After Redeem");
        vm.stopPrank();

        assertApproxEqAbs(assetsRedeemed, DEPOSIT_AMOUNT, 1e6, "Alice should redeem approximately the deposited amount");
        assertEq(vault.totalAssets(), 0, "Vault should have no assets after redeem");
        assertEq(shares.totalSupply(), 0, "All shares should be burned after redeem");
    }

    // ============================================================================
    // TEST 2: YIELD DISTRIBUTION
    // ============================================================================

    function test_yieldIncreasesSharePriceAndBenefitsEarlyDepositors() external {
        vm.startPrank(alice);
        IERC4626 vault = IERC4626(address(diamond));
        uint256 aliceShares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        assertEq(aliceShares, 1000 * SHARE_DECIMALS, "Alice should receive 1000 shares for her deposit");
        assertEq(_getPricePerShare(), ASSET_DECIMALS);

        _simulateYield(100 * ASSET_DECIMALS);
        assertApproxEqAbs(_getPricePerShare(), 11e5, 1e4, "Price per share should increase after yield");

        vm.prank(bob);
        uint256 bobShares = vault.deposit(DEPOSIT_AMOUNT, bob);

        assertLt(bobShares, aliceShares, "Bob should receive fewer shares than Alice due to higher price per share");
        assertEq(vault.totalAssets(), 2100 * ASSET_DECIMALS, "Total assets should reflect both deposits and yield");

        vm.prank(alice);
        uint256 aliceAssets = vault.redeem(aliceShares, alice, alice);

        vm.prank(bob);
        uint256 bobAssets = vault.redeem(bobShares, bob, bob);

        assertApproxEqAbs(aliceAssets, 1100 * ASSET_DECIMALS, 1e6, "Alice should redeem approximately 1100 USDC");
        assertApproxEqAbs(bobAssets, 1000 * ASSET_DECIMALS, 1e6, "Bob should redeem approximately 1000 USDC");
    }

    // ============================================================================
    // Facet Selectors
    // ============================================================================

    function _selectorsLoupe() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = bytes4(keccak256("supportsInterface(bytes4)"));
        return selectors;
    }

    function _selectorsOwnership() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
        return selectors;
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
        return selectors;
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
        return selectors;
    }

    function _selectorPause() private pure returns (bytes4[] memory selectors) {
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
        return selectors;
    }
}
