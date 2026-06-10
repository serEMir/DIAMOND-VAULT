// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DiamondVaultDeployment} from "./DiamondVaultDeployment.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDiamondVault is HelperConfig {
    function run() external returns (DiamondVaultDeployment.Deployment memory deployment) {
        address broadcaster = startConfiguredBroadcast();
        HelperConfig.NetworkConfig memory config = getConfig(broadcaster);

        deployment = DiamondVaultDeployment.deploy(config);
        vm.stopBroadcast();

        DiamondVaultDeployment.logDeployment(deployment, config);
    }
}
