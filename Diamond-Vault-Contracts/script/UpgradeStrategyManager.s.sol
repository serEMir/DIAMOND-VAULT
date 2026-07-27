// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {StrategyManagerFacet} from "../src/strategy/facets/StrategyManagerFacet.sol";

/**
 * @notice Deploys a new StrategyManagerFacet, performs a diamondCut replacing/adding
 * the required selectors, and configures the `creExecutor`.
 *
 * Usage:
 *  export PRIVATE_KEY=...
 *  export DIAMOND=0x...
 *  export CRE_RECEIVER=0x...
 *  forge script script/UpgradeStrategyManager.s.sol:UpgradeStrategyManager --broadcast --rpc-url <RPC>
 */
contract UpgradeStrategyManager is Script {
    function run() external {
        address diamond = vm.envAddress("DIAMOND");
        address creReceiver = vm.envAddress("CRE_RECEIVER");

        vm.startBroadcast();
        // 1) Deploy the new facet implementation
        StrategyManagerFacet newFacet = new StrategyManagerFacet();
        address newFacetAddr = address(newFacet);

        // 2) Build selectors arrays
        bytes4[] memory replaceSelectors = new bytes4[](2);
        replaceSelectors[0] = bytes4(keccak256(bytes("allocateToStrategy(bytes32,uint256)")));
        replaceSelectors[1] = bytes4(keccak256(bytes("freeFundsFromStrategy(bytes32,uint256)")));

        bytes4[] memory addSelectors = new bytes4[](2);
        addSelectors[0] = bytes4(keccak256(bytes("setCREExecutor(address)")));
        addSelectors[1] = bytes4(keccak256(bytes("creExecutor()")));

        // 3) Build the cut: Replace existing two selectors, Add two new selectors
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](2);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: newFacetAddr, action: IDiamondCut.FacetCutAction.Replace, functionSelectors: replaceSelectors
        });

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: newFacetAddr, action: IDiamondCut.FacetCutAction.Add, functionSelectors: addSelectors
        });

        // 4) Execute diamondCut as owner
        IDiamondCut(diamond).diamondCut(cut, address(0), "");

        // 5) Configure the CRE executor on the upgraded facet
        StrategyManagerFacet(diamond).setCREExecutor(creReceiver);

        vm.stopBroadcast();
    }
}
