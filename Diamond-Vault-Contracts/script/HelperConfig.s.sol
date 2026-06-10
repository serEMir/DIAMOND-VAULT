// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

abstract contract CodeConstants {
    bytes32 public constant DEFAULT_AAVE_STRATEGY_ID = keccak256("aave-v3-usdc-strategy");
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__MissingAavePool();
    error HelperConfig__MissingAaveAToken();

    struct NetworkConfig {
        address deployer;
        address finalOwner;
        address asset;
        string vaultName;
        string vaultSymbol;
        address guardian;
        address keeper;
        bool registerAaveStrategy;
        bool activateAaveStrategy;
        bytes32 aaveStrategyId;
        address aavePool;
        address aaveAToken;
    }

    function getConfig(address deployer) public view returns (NetworkConfig memory config) {
        config.deployer = deployer;
        config.finalOwner = vm.envOr("DIAMOND_OWNER", config.deployer);
        config.asset = vm.envOr("VAULT_ASSET", address(0));
        config.vaultName = vm.envOr("VAULT_NAME", string("Diamond Vault Share"));
        config.vaultSymbol = vm.envOr("VAULT_SYMBOL", string("DVS"));
        config.guardian = vm.envOr("GUARDIAN", address(0));
        config.keeper = vm.envOr("KEEPER", address(0));
        config.registerAaveStrategy = vm.envOr("REGISTER_AAVE_STRATEGY", false);
        config.activateAaveStrategy = vm.envOr("ACTIVATE_AAVE_STRATEGY", true);
        config.aaveStrategyId = vm.envOr("AAVE_STRATEGY_ID", DEFAULT_AAVE_STRATEGY_ID);
        config.aavePool = vm.envOr("AAVE_POOL", address(0));
        config.aaveAToken = vm.envOr("AAVE_ATOKEN", address(0));

        if (config.registerAaveStrategy && config.aavePool == address(0)) {
            revert HelperConfig__MissingAavePool();
        }
        if (config.registerAaveStrategy && config.aaveAToken == address(0)) {
            revert HelperConfig__MissingAaveAToken();
        }
    }

    function startConfiguredBroadcast() internal returns (address broadcaster) {
        uint256 privateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (privateKey != 0) {
            broadcaster = vm.addr(privateKey);
            vm.startBroadcast(privateKey);
            return broadcaster;
        }

        vm.startBroadcast();
        (, broadcaster,) = vm.readCallers();
    }
}
