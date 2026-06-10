// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LibStrategyKeeperStorage {
    error LibStrategyKeeperStorage__NotKeeper(address caller, address keeper);

    bytes32 internal constant STRATEGY_KEEPER_STORAGE_POSITION = keccak256("diamondvault.strategy.keeper.storage");

    struct StrategyKeeperStorage {
        address keeper;
    }

    function strategyKeeperStorage() internal pure returns (StrategyKeeperStorage storage sks) {
        bytes32 position = STRATEGY_KEEPER_STORAGE_POSITION;
        assembly {
            sks.slot := position
        }
    }

    function keeper() internal view returns (address keeper_) {
        keeper_ = strategyKeeperStorage().keeper;
    }

    function setKeeper(address newKeeper) internal returns (address previousKeeper) {
        StrategyKeeperStorage storage sks = strategyKeeperStorage();
        previousKeeper = sks.keeper;
        sks.keeper = newKeeper;
    }

    function enforceIsKeeper() internal view {
        address keeper_ = keeper();
        if (msg.sender != keeper_) {
            revert LibStrategyKeeperStorage__NotKeeper(msg.sender, keeper_);
        }
    }
}
