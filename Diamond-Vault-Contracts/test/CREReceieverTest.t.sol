// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CREReceiver, ICREReceiver} from "../src/cre/CREReceiver.sol";

import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockYieldSource} from "../src/mocks/MockYieldSource.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {VaultShareFacet} from "../src/vault/facets/VaultShareFacet.sol";
import {Vault4626Facet} from "../src/vault/facets/Vault4626Facet.sol";
import {VaultPauseFacet} from "../src/vault/facets/VaultPauseFacet.sol";
import {IVaultPauseAdmin} from "../src/vault/interfaces/IVaultPauseAdmin.sol";
import {VaultInit} from "../src/vault/upgrade/VaultInit.sol";

import {IStrategyKeeper} from "../src/strategy/interfaces/IStrategyKeeper.sol";
import {IStrategyManager} from "../src/strategy/interfaces/IStrategyManager.sol";
import {IMockStrategyFacet} from "../src/strategy/interfaces/IMockStrategyFacet.sol";
import {StrategyManagerFacet} from "../src/strategy/facets/StrategyManagerFacet.sol";
import {StrategyKeeperFacet} from "../src/strategy/facets/StrategyKeeperFacet.sol";
import {MockStrategyFacet} from "../src/strategy/facets/MockStrategyFacet.sol";

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/diamond/facets/OwnershipFacet.sol";
import {DiamondInit} from "../src/diamond/upgrade/DiamondInit.sol";
import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";
import {IERC165} from "../src/diamond/interfaces/IERC165.sol";

contract CREReceiverTest is Test {
    address private owner = makeAddr("owner");
    address private creForwarder = makeAddr("creForwarder");
    address private attacker = makeAddr("attacker");
    address private alice = makeAddr("ALICE");

    Diamond private diamond;
    MockUSDC private usdc;
    MockYieldSource private source;
    CREReceiver private receiver;

    uint256 private constant ONE_USDC = 1e6;
    bytes32 private constant MOCK_STRATEGY_ID = keccak256("mock-usdc-strategy");

    event ReportExecuted(bytes32 indexed reportId, bytes payload);

    // ============================================================================
    // SET UP
    // ============================================================================

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
        StrategyManagerFacet sMFacet = new StrategyManagerFacet();
        StrategyKeeperFacet sKFacet = new StrategyKeeperFacet();
        MockStrategyFacet mockStrategyFacet = new MockStrategyFacet();
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
            facetAddress: address(sMFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsStrategyManager()
        });

        cut[6] = IDiamondCut.FacetCut({
            facetAddress: address(sKFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsStrategyKeeper()
        });

        cut[7] = IDiamondCut.FacetCut({
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
                abi.encodeWithSelector(VaultInit.init.selector, address(usdc), "Diamond Vault Share", "DVSHARE")
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
        receiver = new CREReceiver(address(diamond), creForwarder);

        // The diamond sees msg.sender as the receiver, not the CRE forwarder.
        IStrategyKeeper(address(diamond)).setKeeper(address(receiver));

        vm.stopPrank();

        usdc.mint(alice, 1000 * ONE_USDC);

        vm.prank(alice);
        usdc.approve(address(diamond), type(uint256).max);
    }
    // ============================================================================
    // Helper Functions
    // ============================================================================

    function _depositAndAllocate() private {
        IERC4626 vault = IERC4626(address(diamond));
        IStrategyManager strategyManager = IStrategyManager(address(diamond));

        vm.prank(alice);
        vault.deposit(100 * ONE_USDC, alice);

        vm.prank(owner);
        strategyManager.allocateToStrategy(MOCK_STRATEGY_ID, 60 * ONE_USDC);
    }

    function _harvestReport() private pure returns (bytes memory) {
        return abi.encodeWithSelector(IStrategyKeeper.keeperHarvestStrategy.selector, MOCK_STRATEGY_ID);
    }

    // ============================================================================
    // TESTS
    // ============================================================================
    function test_forwarderCanExecuteKeeperHarvestReport() external {
        _depositAndAllocate();

        source.setReportedAssets(address(diamond), 70 * ONE_USDC);

        bytes memory metadata = abi.encode("workflow-id", uint256(1));
        bytes memory report = _harvestReport();
        bytes32 reportKey = keccak256(abi.encode(metadata, report));

        vm.expectEmit(true, false, false, true, address(receiver));
        emit ReportExecuted(reportKey, report);

        vm.prank(creForwarder);
        receiver.onReport(metadata, report);

        assertTrue(receiver.hasExecuted(reportKey));

        (,,,, uint256 debt,,,) = IStrategyManager(address(diamond)).strategyState(MOCK_STRATEGY_ID);
        assertEq(debt, 70 * ONE_USDC, "Debt should be updated to reported assets");
        assertEq(
            IStrategyManager(address(diamond)).totalStrategyDebt(),
            70 * ONE_USDC,
            "Total strategy debt should be updated"
        );
    }

    function test_nonForwarderCannotSubmitReport() external {
        bytes memory metadata = abi.encode("workflow-id", uint256(1));
        bytes memory report = _harvestReport();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(CREReceiver.CREReceiver__UnauthorizedCaller.selector, attacker, creForwarder)
        );
        receiver.onReport(metadata, report);
    }

    function test_rejectsReplay() external {
        _depositAndAllocate();

        bytes memory metadata = abi.encode("workflow-id", uint256(1));
        bytes memory report = _harvestReport();
        bytes32 reportKey = keccak256(abi.encode(metadata, report));

        vm.prank(creForwarder);
        receiver.onReport(metadata, report);

        vm.prank(creForwarder);
        vm.expectRevert(abi.encodeWithSelector(CREReceiver.CREReceiver__ReportAlreadyExecuted.selector, reportKey));
        receiver.onReport(metadata, report);
    }

    function test_rejectsWrongSelector() external {
        bytes memory metadata = abi.encode("workflow-id", uint256(1));

        bytes memory report = abi.encodeWithSelector(bytes4(keccak256("badFunction(bytes32)")), MOCK_STRATEGY_ID);

        bytes4 selector;
        assembly {
            selector := mload(add(report, 32))
        }

        vm.prank(creForwarder);
        vm.expectRevert(abi.encodeWithSelector(CREReceiver.CREReceiver__InvalidSelector.selector, selector));

        receiver.onReport(metadata, report);
    }

    function test_rejectsMalformedPayload() external {
        bytes memory metadata = abi.encode("workflow-id", uint256(1));
        bytes memory report = hex"12345678";

        vm.prank(creForwarder);
        vm.expectRevert(abi.encodeWithSelector(CREReceiver.CREReceiver__InvalidReportPayload.selector, report));
        receiver.onReport(metadata, report);
    }

    function test_revertsIfDiamondKeeperIsNotReceiver() external {
        address wrongKeeper = address(0xBEEF);

        vm.prank(owner);
        IStrategyKeeper(address(diamond)).setKeeper(wrongKeeper);

        bytes memory metadata = abi.encode("workflow-id", uint256(1));
        bytes memory report = _harvestReport();

        vm.prank(creForwarder);
        vm.expectRevert();
        receiver.onReport(metadata, report);
    }

    function test_supportsCREReceiverInterface() external view {
        assertTrue(receiver.supportsInterface(type(ICREReceiver).interfaceId));
        // assertTrue(receiver.supportsInterface(type(IERC165).interfaceId));
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
        selectors[4] = IERC165.supportsInterface.selector;
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

    function _selectorsMockStrategy() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](5);
        selectors[0] = IMockStrategyFacet.setMockStrategySource.selector;
        selectors[1] = IMockStrategyFacet.mockStrategySource.selector;
        selectors[2] = IMockStrategyFacet.mockStrategyDeploy.selector;
        selectors[3] = IMockStrategyFacet.mockStrategyFreeFunds.selector;
        selectors[4] = IMockStrategyFacet.mockStrategyHarvest.selector;
    }
}
