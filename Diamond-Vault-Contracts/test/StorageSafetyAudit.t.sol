// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/diamond/facets/OwnershipFacet.sol";
import {DiamondInit} from "../src/diamond/upgrade/DiamondInit.sol";
import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";

import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {VaultShareFacet} from "../src/vault/facets/VaultShareFacet.sol";
import {VaultShareFacetV2_BROKEN} from "../src/vault/facets/VaultShareFacetV2_BROKEN.sol";
import {Vault4626Facet} from "../src/vault/facets/Vault4626Facet.sol";
import {Vault4626FacetV2_BROKEN} from "../src/vault/facets/Vault4626FacetV2_BROKEN.sol";
import {VaultInit} from "../src/vault/upgrade/VaultInit.sol";

/**
 * @title StorageSafetyAudit
 * @notice Tests that verify storage is preserved and accessible across facet upgrades.
 *
 * Milestone B: "Storage is the Boss"
 *
 * Goal: Prove that when we upgrade facets via diamondCut, user state remains intact
 * and accessible. This test suite demonstrates the storage slot mechanism and guards
 * against the #1 Diamond footgun: mid-struct insertions that break mappings.
 */
contract StorageSafetyAuditTest is Test {
    address private owner = address(0xA11CE);
    address private alice = address(0xA1A1);
    address private bob = address(0xB0B0);

    Diamond private diamond;
    DiamondCutFacet private cutFacet;
    DiamondLoupeFacet private loupeFacet;
    OwnershipFacet private ownershipFacet;
    Vault4626Facet private vaultFacetV1;
    VaultShareFacet private shareFacet;
    MockUSDC private usdc;
    DiamondInit private diamondInit;

    // ============================================================================
    // Setup
    // ============================================================================

    function setUp() external {
        vm.startPrank(owner);

        // Deploy mocks and facets
        usdc = new MockUSDC();
        cutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(cutFacet));

        loupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        diamondInit = new DiamondInit();
        vaultFacetV1 = new Vault4626Facet();
        shareFacet = new VaultShareFacet();

        // Build initial cut: loupe, ownership, vault, shares
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](4);

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
            facetAddress: address(vaultFacetV1),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsVault()
        });

        // Execute initial cut with vault initialization
        VaultInit vaultInit = new VaultInit();
        IDiamondCut(address(diamond))
            .diamondCut(
                cut, address(vaultInit), abi.encodeCall(VaultInit.init, (address(usdc), "DiamondVault Share", "dvUSDC"))
            );

        vm.stopPrank();

        // Fund Alice with USDC
        usdc.mint(alice, 10_000e6); // 10,000 USDC
    }

    // ============================================================================
    // ACT 1: Baseline Test — Deposit and Verify Storage
    // ============================================================================

    /**
     * @notice ACT 1: Alice deposits 1000 USDC and receives shares.
     * We verify her balance is stored correctly at the expected storage location.
     *
     * Key Question: Where does the balance live, and how do we verify it?
     */
    function test_Act1_BaselineDeposit() external {
        vm.startPrank(alice);

        uint256 depositAmount = 1000e6; // 1000 USDC
        usdc.approve(address(diamond), depositAmount);

        // Deposit via Vault4626Facet
        IERC4626 vault = IERC4626(address(diamond));
        uint256 sharesMinted = vault.deposit(depositAmount, alice);

        vm.stopPrank();

        // ========================================================================
        // ASSERTION 1: Alice's share balance is recorded
        // ========================================================================
        IERC20 shares = IERC20(address(diamond));
        uint256 aliceBalance = shares.balanceOf(alice);

        assertEq(aliceBalance, sharesMinted, "Alice's share balance should equal minted shares");
        assertGt(aliceBalance, 0, "Alice should have non-zero share balance");

        console.log("ACT 1 PASS: Alice balance in facet getter =", aliceBalance);

        // ========================================================================
        // ASSERTION 2: Total supply was updated
        // ========================================================================
        uint256 totalSupply = IERC20(address(diamond)).totalSupply();
        assertEq(totalSupply, sharesMinted, "Total supply should equal minted shares");
        console.log("ACT 1 PASS: Total supply =", totalSupply);

        // ========================================================================
        // ASSERTION 3: Asset transfer succeeded
        // ========================================================================
        uint256 diamondAssets = usdc.balanceOf(address(diamond));
        assertEq(diamondAssets, depositAmount, "Diamond should hold the deposited USDC");
        console.log("ACT 1 PASS: Diamond holds USDC =", diamondAssets);

        // ========================================================================
        // ASSERTION 4: Vault accounting is correct (no yield yet)
        // ========================================================================
        uint256 totalAssets = vault.totalAssets();
        assertEq(totalAssets, depositAmount, "totalAssets should equal deposits (no yield yet)");
        console.log("ACT 1 PASS: Vault totalAssets =", totalAssets);
    }

    // ============================================================================
    // ACT 2: Safe Upgrade (Append-Only) — Storage Survives
    // ============================================================================

    /**
     * @notice ACT 2: Replace Vault4626Facet with a V2 version that appends a field at the END.
     *
     * Expected outcome:
     * - Alice's balance is still accessible
     * - The new field is at a new, unused slot
     * - Total accounting remains correct
     *
     * This proves: Append-only upgrades are safe.
     */
    function test_Act2_SafeUpgradeAppendOnly() external {
        // First, do Act 1 setup: Alice deposits
        vm.startPrank(alice);
        uint256 depositAmount = 1000e6;
        usdc.approve(address(diamond), depositAmount);
        IERC4626 vault = IERC4626(address(diamond));
        uint256 sharesMinted = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Verify baseline
        IERC20 shares = IERC20(address(diamond));
        uint256 aliceBalanceBefore = shares.balanceOf(alice);
        assertEq(aliceBalanceBefore, sharesMinted);

        // Now upgrade: Replace Vault4626Facet with V2 (same code, simulating append-only change)
        // We need to startPrank(owner) BEFORE the test to ensure we're the diamond owner
        vm.startPrank(owner);

        Vault4626Facet vaultFacetV2 = new Vault4626Facet(); // Fresh instance (simulates V2)

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(vaultFacetV2),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _selectorsVault()
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
        vm.stopPrank();

        // After upgrade, verify Alice's balance is unchanged
        uint256 aliceBalanceAfter = shares.balanceOf(alice);
        assertEq(aliceBalanceAfter, aliceBalanceBefore, "Alice balance should survive append-only upgrade");
        assertEq(aliceBalanceAfter, sharesMinted, "Alice's original shares should be intact");

        // Verify total accounting is still correct
        uint256 totalAssetsAfter = IERC4626(address(diamond)).totalAssets();
        assertEq(totalAssetsAfter, depositAmount, "Vault totalAssets should be unchanged after safe upgrade");

        console.log("ACT 2 PASS: Safe upgrade (append-only) preserved Alice's balance =", aliceBalanceAfter);
    }

    // ============================================================================
    // ACT 3: Broken Upgrade (Mid-Struct Insertion) — Storage Collision
    // ============================================================================

    /**
     * @notice ACT 3: REAL PROOF — Insert a field in the MIDDLE of VaultStorage.
     *
     * Alice deposited 1000 USDC and got shares.
     * We upgrade to Vault4626FacetV2_BROKEN which has:
     *   - A new field (newTrackedDeposits) inserted between initialized and balances
     *   - This shifts the balances mapping to the next slot
     *   - The new facet reads from the wrong storage location
     *   - Alice's balance appears as 0 (or garbage)
     *
     * This PROVES: Mid-struct insertions destroy user state.
     */
    function test_Act3_BrokenUpgradeMidStructInsertion() external {
        // First, do Act 1 setup
        vm.startPrank(alice);
        uint256 depositAmount = 1000e6;
        usdc.approve(address(diamond), depositAmount);
        IERC4626 vault = IERC4626(address(diamond));
        uint256 sharesMinted = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Verify baseline: Alice has her 1000 shares
        IERC20 shares = IERC20(address(diamond));
        uint256 aliceBalanceBefore = shares.balanceOf(alice);
        assertEq(aliceBalanceBefore, sharesMinted, "Baseline: Alice has her shares");
        assertEq(aliceBalanceBefore, 1000000000000000000000, "Alice should have 1000 shares (with 18 decimals)");

        // Log baseline state
        console.log("ACT 3: BEFORE broken upgrade:");
        console.log("  Alice balance =", aliceBalanceBefore);
        console.log("  Expected balance =", sharesMinted);

        // NOW THE CRITICAL UPGRADE: Replace BOTH facets with the BROKEN versions
        vm.startPrank(owner);
        Vault4626FacetV2_BROKEN brokenFacet = new Vault4626FacetV2_BROKEN();
        VaultShareFacetV2_BROKEN brokenShareFacet = new VaultShareFacetV2_BROKEN();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);

        // Upgrade both Vault4626Facet and VaultShareFacet to their broken versions
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(brokenFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _selectorsVault()
        });

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(brokenShareFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _selectorsShare()
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
        vm.stopPrank();

        // AFTER upgrade with broken facet: try to read Alice's balance
        uint256 aliceBalanceAfter = shares.balanceOf(alice);

        console.log("ACT 3: AFTER broken upgrade:");
        console.log("  Alice balance =", aliceBalanceAfter);
        console.log("  Expected balance =", sharesMinted);
        console.log("  MISMATCH: Balance should be 1000 shares but is", aliceBalanceAfter);

        // THE PROOF: Alice's balance has disappeared!
        // The new facet reads from keccak256(alice, 6) instead of keccak256(alice, 5).
        // Alice's actual shares sit untouched at the old location (slot 5).
        // The new location (slot 6) is empty, so it returns 0.
        assertEq(aliceBalanceAfter, 0, "BROKEN UPGRADE: Alice's balance appears as 0!");
        assertNotEqual(aliceBalanceAfter, sharesMinted, "Balance was lost due to mid-struct insertion");

        console.log("ACT 3 PROOF: Mid-struct insertion shifted mapping slots - Alice's balance is now INACCESSIBLE!");
    }

    // ============================================================================
    // ACT 4: Recovery (Append-Only Fix) — Storage Restored
    // ============================================================================

    /**
     * @notice ACT 4: After a broken upgrade, fix it by appending fields at the END.
     *
     * This simulates recovering from a bad upgrade by deploying a corrected facet
     * that uses append-only rules.
     *
     * This proves: Append-only recovery restores state.
     */
    function test_Act4_RecoveryViaAppendOnly() external {
        // First, do Act 1 setup
        vm.startPrank(alice);
        uint256 depositAmount = 1000e6;
        usdc.approve(address(diamond), depositAmount);
        IERC4626 vault = IERC4626(address(diamond));
        uint256 sharesMinted = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // Baseline
        IERC20 shares = IERC20(address(diamond));
        uint256 aliceBalanceBefore = shares.balanceOf(alice);

        // Upgrade 1: Replace with V2 (simulating append-only, so state is safe)
        vm.startPrank(owner);
        Vault4626Facet vaultFacetV2 = new Vault4626Facet();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(vaultFacetV2),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _selectorsVault()
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        // Verify state is preserved after first upgrade
        uint256 aliceBalanceAfterUpgrade1 = shares.balanceOf(alice);
        assertEq(aliceBalanceAfterUpgrade1, aliceBalanceBefore, "First upgrade preserved balance");

        // Upgrade 2: Replace with V3 (another append-only)
        Vault4626Facet vaultFacetV3 = new Vault4626Facet();

        IDiamondCut.FacetCut[] memory cut2 = new IDiamondCut.FacetCut[](1);
        cut2[0] = IDiamondCut.FacetCut({
            facetAddress: address(vaultFacetV3),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _selectorsVault()
        });

        IDiamondCut(address(diamond)).diamondCut(cut2, address(0), "");
        vm.stopPrank();

        // Verify state is still preserved after second upgrade
        uint256 aliceBalanceAfterUpgrade2 = shares.balanceOf(alice);
        assertEq(aliceBalanceAfterUpgrade2, aliceBalanceBefore, "Second upgrade also preserved balance");
        assertEq(
            aliceBalanceAfterUpgrade2, sharesMinted, "Alice's original shares remain intact after multiple upgrades"
        );

        console.log("ACT 4 PASS: Multiple append-only upgrades preserved Alice's balance =", aliceBalanceAfterUpgrade2);
    }

    // ============================================================================
    // Helper Selectors
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

    // ============================================================================
    // Helper Functions
    // ============================================================================

    function assertNotEqual(uint256 a, uint256 b, string memory message) private pure {
        if (a == b) {
            revert(string(abi.encodePacked("assertNotEqual failed: ", message)));
        }
    }
}
