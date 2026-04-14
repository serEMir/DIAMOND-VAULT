// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MockYieldSource
 * @notice Minimal yield-source mock used to simulate strategy deposits, withdrawals, and reported asset changes.
 */
contract MockYieldSource {
    using SafeERC20 for IERC20;

    /**
     * @notice The asset token accepted and returned by the yield source.
     */
    IERC20 public immutable asset;

    /**
     * @notice Reported assets tracked per depositor.
     */
    mapping(address => uint256) public reportedAssets;

    /**
     * @notice Sets the asset used by the yield source.
     * @param asset_ The asset token accepted by the mock yield source.
     */
    constructor(address asset_) {
        asset = IERC20(asset_);
    }

    /**
     * @notice Returns the assets reported for an account.
     * @param account The account to query.
     * @return assets_ The reported assets for the account.
     */
    function reportedAssetsOf(address account) external view returns (uint256 assets_) {
        assets_ = reportedAssets[account];
    }

    /**
     * @notice Deposits assets into the mock yield source and increases reported assets.
     * @param assets The amount of assets to deposit.
     */
    function deposit(uint256 assets) external {
        asset.safeTransferFrom(msg.sender, address(this), assets);
        reportedAssets[msg.sender] += assets;
    }

    /**
     * @notice Withdraws up to the requested assets, bounded by the caller's position and current liquidity.
     * @param assets The amount of assets requested.
     * @return withdrawnAssets The amount of assets actually withdrawn.
     */
    function withdraw(uint256 assets) external returns (uint256 withdrawnAssets) {
        uint256 position = reportedAssets[msg.sender];
        uint256 liquidAssets = asset.balanceOf(address(this));

        withdrawnAssets = assets;
        if (withdrawnAssets > position) {
            withdrawnAssets = position;
        }
        if (withdrawnAssets > liquidAssets) {
            withdrawnAssets = liquidAssets;
        }

        reportedAssets[msg.sender] = position - withdrawnAssets;
        if (withdrawnAssets != 0) {
            asset.safeTransfer(msg.sender, withdrawnAssets);
        }
    }

    /**
     * @notice Manually sets the reported assets for an account.
     * @param account The account whose reported assets should be updated.
     * @param assets The new reported asset amount.
     */
    function setReportedAssets(address account, uint256 assets) external {
        reportedAssets[account] = assets;
    }
}
