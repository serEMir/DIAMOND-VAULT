// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CREReceiver} from "../src/cre/CREReceiver.sol";

contract DeployCREReceiver is HelperConfig {
    struct DeploymentConfig {
        address diamond;
        address creForwarder;
    }

    function run() external returns (address receiver) {
        address broadcaster = startConfiguredBroadcast();
        DeploymentConfig memory config = getDeploymentConfig();

        receiver = _deployCREReceiver(config);
        vm.stopBroadcast();

        logDeployment(receiver, config);
    }

    function getDeploymentConfig() internal view returns (DeploymentConfig memory config) {
        config.diamond = vm.envAddress("DIAMOND");
        config.creForwarder = vm.envAddress("CRE_FORWARDER");

        require(config.diamond != address(0), "DIAMOND environment variable not set");
        require(config.creForwarder != address(0), "CRE_FORWARDER environment variable not set");
    }

    function _deployCREReceiver(DeploymentConfig memory config) internal returns (address) {
        CREReceiver receiver = new CREReceiver(config.diamond, config.creForwarder);
        return address(receiver);
    }

    function logDeployment(address receiver, DeploymentConfig memory config) internal view {
        console2.log("CREReceiver deployed");
        console2.log("receiver", receiver);
        console2.log("diamond", config.diamond);
        console2.log("creForwarder", config.creForwarder);
    }
}
