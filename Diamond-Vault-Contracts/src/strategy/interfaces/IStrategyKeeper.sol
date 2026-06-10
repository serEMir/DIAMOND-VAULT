// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategyKeeper {
    event KeeperUpdated(address indexed previousKeeper, address indexed newKeeper);
    event StrategyHarvested(
        bytes32 indexed strategyId, uint256 previousDebt, uint256 reportedDebt, uint256 gain, uint256 loss
    );

    function keeper() external view returns (address keeper_);
    function setKeeper(address newKeeper) external;
    function keeperHarvestStrategy(bytes32 strategyId)
        external
        returns (uint256 reportedAssets, uint256 gain, uint256 loss);
}
