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
import {VaultShareFacet} from "../src/vault/facets/VaultShareFacet.sol";
import {Vault4626Facet} from "../src/vault/facets/Vault4626Facet.sol";
import {VaultPauseFacet} from "../src/vault/facets/VaultPauseFacet.sol";
import {IVaultPauseAdmin} from "../src/vault/interfaces/IVaultPauseAdmin.sol";
import {VaultInit} from "../src/vault/upgrade/VaultInit.sol";

contract Vault4626DiamondTest is Test {
    address private owner = address(0xA11CE);
    address private guardian = address(0xCAFE);
    address private alice = address(0xA11CEA);
    address private bob = address(0xB0B);

    uint256 private constant ONE_USDC = 1e6;
    uint256 private constant ONE_SHARE = 1e18;

    Diamond private diamond;
    MockUSDC private usdc;

    function setUp() external {
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(cutFacet));
        usdc = new MockUSDC();

        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        DiamondInit diamondInit = new DiamondInit();
        VaultShareFacet shareFacet = new VaultShareFacet();
        Vault4626Facet vaultFacet = new Vault4626Facet();
        VaultPauseFacet pauseFacet = new VaultPauseFacet();
        VaultInit vaultInit = new VaultInit();

        vm.startPrank(owner);

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

        IDiamondCut(address(diamond))
            .diamondCut(cut, address(diamondInit), abi.encodeWithSelector(DiamondInit.init.selector));
        IDiamondCut(address(diamond))
            .diamondCut(
                new IDiamondCut.FacetCut[](0),
                address(vaultInit),
                abi.encodeWithSelector(VaultInit.init.selector, address(usdc), "Diamond Vault Share", "DVS")
            );

        vm.stopPrank();

        usdc.mint(alice, 1_000 * ONE_USDC);
        usdc.mint(bob, 1_000 * ONE_USDC);

        vm.prank(alice);
        usdc.approve(address(diamond), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(diamond), type(uint256).max);
    }

    // =============================================================================
    // TESTS
    // =============================================================================
    function test_initialDepositUsesOneToOneWholeTokenPricing() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20Metadata shareToken = IERC20Metadata(address(diamond));

        vm.prank(alice);
        uint256 mintedShares = vault.deposit(100 * ONE_USDC, alice);

        assertEq(mintedShares, 100 * ONE_SHARE);
        assertEq(shareToken.balanceOf(alice), 100 * ONE_SHARE);
        assertEq(vault.totalAssets(), 100 * ONE_USDC);
        assertEq(shareToken.decimals(), 18);
        assertEq(vault.asset(), address(usdc));
    }

    function test_bobDepositAfterYieldGetsFewerShares() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        usdc.mint(address(diamond), 10 * ONE_USDC);

        vm.prank(bob);
        uint256 bobShares = vault.deposit(100 * ONE_USDC, bob);

        assertEq(bobShares, 90_909090909090909090);
        assertEq(shareToken.balanceOf(alice), 100 * ONE_SHARE);
        assertEq(shareToken.balanceOf(bob), 90_909090909090909090);
        assertEq(vault.totalAssets(), 210 * ONE_USDC);
        assertEq(vault.convertToAssets(shareToken.balanceOf(alice)), 110 * ONE_USDC);
        assertEq(vault.convertToAssets(shareToken.balanceOf(bob)), 99_999_999);
        assertEq(
            vault.totalAssets() - vault.convertToAssets(shareToken.balanceOf(alice))
                - vault.convertToAssets(shareToken.balanceOf(bob)),
            1
        );
    }

    function test_previewDepositRoundsDownInFavorOfVault() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));

        vm.prank(alice);
        vault.deposit(2 * ONE_USDC, alice);

        usdc.mint(address(diamond), ONE_USDC);

        uint256 previewShares = vault.previewDeposit(ONE_USDC);

        vm.prank(bob);
        uint256 mintedShares = vault.deposit(ONE_USDC, bob);

        assertEq(previewShares, 666666666666666666);
        assertEq(mintedShares, previewShares);
        assertEq(shareToken.balanceOf(bob), 666666666666666666);
    }

    function test_previewWithdrawRoundsUpSharesBurned() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        usdc.mint(address(diamond), 10 * ONE_USDC);

        uint256 sharesBefore = shareToken.balanceOf(alice);
        uint256 previewShares = vault.previewWithdraw(ONE_USDC);

        vm.prank(alice);
        uint256 burnedShares = vault.withdraw(ONE_USDC, alice, alice);

        assertEq(previewShares, 909090909090909091);
        assertEq(burnedShares, previewShares);
        assertEq(shareToken.balanceOf(alice), sharesBefore - previewShares);
        assertEq(usdc.balanceOf(alice), 901 * ONE_USDC);
    }

    function test_depositWithoutApprovalRevertsBeforeMinting() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));
        address charlie = address(0xCA11E);

        usdc.mint(charlie, 10 * ONE_USDC);

        vm.prank(charlie);
        vm.expectRevert();
        vault.deposit(ONE_USDC, charlie);

        assertEq(shareToken.totalSupply(), 0);
        assertEq(shareToken.balanceOf(charlie), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function test_ownerCanPauseDepositsAndMints() external {
        IERC4626 vault = IERC4626(address(diamond));
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(owner);
        pauseAdmin.setDepositsPaused(true);

        assertTrue(pauseAdmin.depositsPaused());
        assertEq(vault.maxDeposit(alice), 0);
        assertEq(vault.maxMint(alice), 0);

        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(ONE_USDC, alice);

        vm.prank(alice);
        vm.expectRevert();
        vault.mint(ONE_SHARE, alice);
    }

    function test_ownerCanSetGuardian() external {
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(owner);
        pauseAdmin.setGuardian(guardian);

        assertEq(pauseAdmin.guardian(), guardian);
    }

    function test_ownerCanPauseWithdrawalsAndRedeems() external {
        IERC4626 vault = IERC4626(address(diamond));
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        pauseAdmin.setWithdrawalsPaused(true);

        assertTrue(pauseAdmin.withdrawalsPaused());
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxRedeem(alice), 0);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(ONE_USDC, alice, alice);

        vm.prank(alice);
        vm.expectRevert();
        vault.redeem(ONE_SHARE, alice, alice);
    }

    function test_ownerCanPauseShareTransfersWithoutBlockingApprovals() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        pauseAdmin.setShareTransfersPaused(true);

        assertTrue(pauseAdmin.shareTransfersPaused());

        vm.prank(alice);
        assertTrue(shareToken.approve(bob, 10 * ONE_SHARE));

        vm.prank(alice);
        vm.expectRevert();
        shareToken.transfer(bob, 10 * ONE_SHARE);

        vm.prank(bob);
        vm.expectRevert();
        shareToken.transferFrom(alice, bob, 10 * ONE_SHARE);
    }

    function test_guardianCanPauseButCannotUnpause() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        pauseAdmin.setGuardian(guardian);

        vm.startPrank(guardian);
        pauseAdmin.setDepositsPaused(true);
        pauseAdmin.setWithdrawalsPaused(true);
        pauseAdmin.setShareTransfersPaused(true);
        vm.stopPrank();

        assertTrue(pauseAdmin.depositsPaused());
        assertTrue(pauseAdmin.withdrawalsPaused());
        assertTrue(pauseAdmin.shareTransfersPaused());

        vm.prank(guardian);
        vm.expectRevert();
        pauseAdmin.setDepositsPaused(false);

        vm.prank(guardian);
        vm.expectRevert();
        pauseAdmin.setWithdrawalsPaused(false);

        vm.prank(guardian);
        vm.expectRevert();
        pauseAdmin.setShareTransfersPaused(false);

        vm.prank(owner);
        pauseAdmin.setDepositsPaused(false);

        vm.prank(owner);
        pauseAdmin.setWithdrawalsPaused(false);

        vm.prank(owner);
        pauseAdmin.setShareTransfersPaused(false);

        vm.prank(alice);
        uint256 burnedShares = vault.withdraw(ONE_USDC, alice, alice);

        assertGt(burnedShares, 0);

        vm.prank(alice);
        assertTrue(shareToken.transfer(bob, ONE_SHARE));
    }

    function test_nonOwnerCannotTogglePauseState() external {
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(alice);
        vm.expectRevert();
        pauseAdmin.setDepositsPaused(true);
    }

    function test_nonGuardianCannotPauseAfterGuardianConfigured() external {
        IVaultPauseAdmin pauseAdmin = IVaultPauseAdmin(address(diamond));

        vm.prank(owner);
        pauseAdmin.setGuardian(guardian);

        vm.prank(alice);
        vm.expectRevert();
        pauseAdmin.setWithdrawalsPaused(true);
    }

    function test_delegatedWithdrawUsesSharesAllowance() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(alice);
        shareToken.approve(bob, 50 * ONE_SHARE);

        uint256 bobAssetsBefore = usdc.balanceOf(bob);

        vm.prank(bob);
        uint256 burnedShares = vault.withdraw(20 * ONE_USDC, bob, alice);

        assertEq(burnedShares, 20 * ONE_SHARE);
        assertEq(usdc.balanceOf(bob), bobAssetsBefore + 20 * ONE_USDC);
        assertEq(shareToken.balanceOf(alice), 80 * ONE_SHARE);
        assertEq(shareToken.allowance(alice, bob), 30 * ONE_SHARE);
        assertEq(vault.totalAssets(), 80 * ONE_USDC);
    }

    function test_delegatedRedeemUsesSharesAllowance() external {
        IERC4626 vault = IERC4626(address(diamond));
        IERC20 shareToken = IERC20(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(alice);
        shareToken.approve(bob, 50 * ONE_SHARE);

        uint256 bobAssetsBefore = usdc.balanceOf(bob);

        vm.prank(bob);
        uint256 redeemedAssets = vault.redeem(20 * ONE_SHARE, bob, alice);

        assertEq(redeemedAssets, 20 * ONE_USDC);
        assertEq(usdc.balanceOf(bob), bobAssetsBefore + 20 * ONE_USDC);
        assertEq(shareToken.balanceOf(alice), 80 * ONE_SHARE);
        assertEq(shareToken.allowance(alice, bob), 30 * ONE_SHARE);
        assertEq(vault.totalAssets(), 80 * ONE_USDC);
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
}
