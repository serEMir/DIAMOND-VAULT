// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CREReceiver} from "../src/cre/CREReceiver.sol";
import {IStrategyKeeper} from "../src/strategy/interfaces/IStrategyKeeper.sol";
import {IERC173} from "../src/diamond/interfaces/IERC173.sol";

contract DeployCREReceiver is HelperConfig {
    error DeployCREReceiver__BroadcasterIsNotDiamondOwner(address broadcaster, address owner);

    struct DeploymentConfig {
        address diamond;
        address creForwarder;
    }

    function run() external returns (address receiver) {
        DeploymentConfig memory config = getDeploymentConfig();
        address broadcaster = startConfiguredBroadcast();

        address diamondOwner = IERC173(config.diamond).owner();
        if (broadcaster != diamondOwner) {
            revert DeployCREReceiver__BroadcasterIsNotDiamondOwner(broadcaster, diamondOwner);
        }

        receiver = _deployCREReceiver(config);

        // This calls setKeeper on the Diamond through its installed keeper facet.
        IStrategyKeeper(config.diamond).setKeeper(receiver);

        vm.stopBroadcast();

        logDeployment(receiver, config);
    }

    function getDeploymentConfig() internal view returns (DeploymentConfig memory config) {
        config.diamond = vm.envAddress("DIAMOND");
        config.creForwarder = vm.envAddress("CRE_FORWARDER");

        require(config.diamond != address(0), "DIAMOND environment variable not set");
        require(config.creForwarder != address(0), "CRE_FORWARDER environment variable not set");
        require(config.diamond.code.length != 0, "DIAMOND is not a contract");
        require(config.creForwarder.code.length != 0, "CRE_FORWARDER is not a contract");
    }

    function _deployCREReceiver(DeploymentConfig memory config) internal returns (address) {
        CREReceiver receiver = new CREReceiver(config.diamond, config.creForwarder);
        return address(receiver);
    }

    function logDeployment(address receiver, DeploymentConfig memory config) internal pure {
        console2.log("CREReceiver deployed");
        console2.log("receiver", receiver);
        console2.log("diamond", config.diamond);
        console2.log("creForwarder", config.creForwarder);
    }
}
