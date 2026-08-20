// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";

import {IDiamondCut} from "../src/diamond/interfaces/IDiamondCut.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

interface ICREExecutorAdmin {
    function creExecutor() external view returns (address);
    function setCREExecutor(address newExecutor) external;
}

contract RemoveCREExecutorAdmin is HelperConfig {
    function run() external {
        address diamond = vm.envAddress("DIAMOND");

        startConfiguredBroadcast();

        address previousExecutor = ICREExecutorAdmin(diamond).creExecutor();
        if (previousExecutor != address(0)) {
            ICREExecutorAdmin(diamond).setCREExecutor(address(0));
        }

        IDiamondCut(diamond).diamondCut(_removeCREExecutorAdminCut(), address(0), "");

        vm.stopBroadcast();

        console2.log("CRE executor cleared and admin selectors removed");
        console2.log("diamond", diamond);
        console2.log("previousCREExecutor", previousExecutor);
        console2.log("removed selector setCREExecutor(address)");
        console2.logBytes4(ICREExecutorAdmin.setCREExecutor.selector);
        console2.log("removed selector creExecutor()");
        console2.logBytes4(ICREExecutorAdmin.creExecutor.selector);
    }

    function _removeCREExecutorAdminCut() private pure returns (IDiamondCut.FacetCut[] memory cut) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ICREExecutorAdmin.setCREExecutor.selector;
        selectors[1] = ICREExecutorAdmin.creExecutor.selector;

        cut = new IDiamondCut.FacetCut[](1);
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: selectors
        });
    }
}
