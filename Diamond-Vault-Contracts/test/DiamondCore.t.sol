// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {Diamond} from "../src/diamond/Diamond.sol";
import {DiamondCutFacet} from "../src/diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/diamond/facets/OwnershipFacet.sol";
import {DiamondInit} from "../src/diamond/upgrade/DiamondInit.sol";
import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/diamond/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";
import {CounterFacet} from "../src/mocks/CounterFacet.sol";
import {CounterFacetV2} from "../src/mocks/CounterFacetV2.sol";

interface ICounter {
    function counter() external view returns (uint256);
    function increment() external;
}

contract DiamondCoreTest is Test {
    address private owner = address(0xA11CE);
    address private attacker = address(0xB0B);

    Diamond private diamond;
    DiamondCutFacet private cutFacet;
    DiamondLoupeFacet private loupeFacet;
    OwnershipFacet private ownershipFacet;
    DiamondInit private diamondInit;
    CounterFacet private counterFacetV1;
    CounterFacetV2 private counterFacetV2;

    function setUp() external {
        vm.startPrank(owner);

        cutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(cutFacet));

        loupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        diamondInit = new DiamondInit();
        counterFacetV1 = new CounterFacet();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](3);
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
            facetAddress: address(counterFacetV1),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _selectorsCounter()
        });

        IDiamondCut(address(diamond))
            .diamondCut(cut, address(diamondInit), abi.encodeWithSelector(DiamondInit.init.selector));
        vm.stopPrank();
    }

    function test_onlyOwnerCanDiamondCut() external {
        counterFacetV2 = new CounterFacetV2();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(counterFacetV2),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _selectorsIncrementOnly()
        });

        vm.prank(attacker);
        vm.expectRevert();
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");
    }

    function test_loupeShowsFacetMapping() external view {
        address[] memory facetAddrs = IDiamondLoupe(address(diamond)).facetAddresses();
        assertEq(facetAddrs.length, 4); // cut facet (in constructor) + loupe + ownership + counter

        address counterImpl = IDiamondLoupe(address(diamond)).facetAddress(ICounter.increment.selector);
        assertEq(counterImpl, address(counterFacetV1));
    }

    function test_replaceFacetPreservesState() external {
        ICounter counter = ICounter(address(diamond));
        counter.increment();
        assertEq(counter.counter(), 1);

        counterFacetV2 = new CounterFacetV2();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(counterFacetV2),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: _selectorsIncrementOnly()
        });

        vm.prank(owner);
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        // State is preserved at the Diamond address.
        assertEq(counter.counter(), 1);

        // New logic is active (increments by 2).
        counter.increment();
        assertEq(counter.counter(), 3);

        // Loupe points to the new facet.
        address counterImpl = IDiamondLoupe(address(diamond)).facetAddress(ICounter.increment.selector);
        assertEq(counterImpl, address(counterFacetV2));
    }

    function test_ownershipFacetWorks() external {
        assertEq(IERC173(address(diamond)).owner(), owner);

        vm.prank(owner);
        IERC173(address(diamond)).transferOwnership(attacker);

        assertEq(IERC173(address(diamond)).owner(), attacker);
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

    function _selectorsCounter() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = ICounter.counter.selector;
        selectors[1] = ICounter.increment.selector;
    }

    function _selectorsIncrementOnly() private pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = ICounter.increment.selector;
    }
}
