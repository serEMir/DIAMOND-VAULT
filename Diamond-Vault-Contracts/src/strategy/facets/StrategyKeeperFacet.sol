// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibDiamond} from "../../diamond/libraries/LibDiamond.sol";
import {LibReentrancyGuard} from "../../vault/libraries/LibReentrancyGuard.sol";
import {IStrategyKeeper} from "../interfaces/IStrategyKeeper.sol";
import {LibStrategyKeeperStorage} from "../libraries/LibStrategyKeeperStorage.sol";
import {LibStrategyStorage} from "../libraries/LibStrategyStorage.sol";

contract StrategyKeeperFacet is IStrategyKeeper {
    function keeper() external view returns (address keeper_) {
        keeper_ = LibStrategyKeeperStorage.keeper();
    }

    function setKeeper(address newKeeper) external {
        LibDiamond.enforceIsContractOwner();
        address previousKeeper = LibStrategyKeeperStorage.setKeeper(newKeeper);
        emit KeeperUpdated(previousKeeper, newKeeper);
    }

    function keeperHarvestStrategy(bytes32 strategyId)
        external
        returns (uint256 reportedAssets, uint256 gain, uint256 loss)
    {
        LibStrategyKeeperStorage.enforceIsKeeper();
        LibReentrancyGuard.enter();

        LibStrategyStorage.StrategyConfig memory strategy = LibStrategyStorage.strategyState(strategyId);
        uint256 previousDebt = strategy.debt;

        (reportedAssets, gain, loss) = LibStrategyStorage.harvestStrategy(strategyId);

        LibReentrancyGuard.exit();

        emit StrategyHarvested(strategyId, previousDebt, reportedAssets, gain, loss);
    }
}
