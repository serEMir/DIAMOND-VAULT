// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";

import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {StrategyKeeperFacet} from "../src/strategy/facets/StrategyKeeperFacet.sol";
import {IStrategyKeeper} from "../src/strategy/interfaces/IStrategyKeeper.sol";
import {DiamondVaultSelectors} from "./DiamondVaultSelectors.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract AddStrategyKeeperFacet is HelperConfig {
    function run() external returns (address strategyKeeperFacet) {
        address diamond = vm.envAddress("DIAMOND");
        address keeper = vm.envOr("KEEPER", address(0));

        startConfiguredBroadcast();

        strategyKeeperFacet = address(new StrategyKeeperFacet());
        IDiamondCut(diamond).diamondCut(_keeperCut(strategyKeeperFacet), address(0), "");

        if (keeper != address(0)) {
            IStrategyKeeper(diamond).setKeeper(keeper);
        }

        vm.stopBroadcast();

        console2.log("StrategyKeeperFacet added");
        console2.log("diamond", diamond);
        console2.log("strategyKeeperFacet", strategyKeeperFacet);
        if (keeper != address(0)) console2.log("keeper", keeper);
    }

    function _keeperCut(address strategyKeeperFacet) private pure returns (IDiamondCut.FacetCut[] memory cut) {
        cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: strategyKeeperFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: DiamondVaultSelectors.strategyKeeper()
        });
    }
}
