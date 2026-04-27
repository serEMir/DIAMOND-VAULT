// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockUSDC} from "./MockUSDC.sol";
import {MockAToken} from "./MockAToken.sol";

/**
 * @title MockAavePool
 * @notice Test double that keeps Aave's supply/withdraw surface while letting tests simulate yield and liquidity shortage.
 */
contract MockAavePool {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    MockAToken public immutable aToken;

    constructor(address asset_) {
        asset = IERC20(asset_);
        aToken = new MockAToken("Mock Aave USDC", "maUSDC", 6, address(this));
    }

    function supply(address asset_, uint256 amount, address onBehalfOf, uint16) external {
        require(asset_ == address(asset), "unexpected asset");
        asset.safeTransferFrom(msg.sender, address(this), amount);
        aToken.mint(onBehalfOf, amount);
    }

    function withdraw(address asset_, uint256 amount, address to) external returns (uint256 withdrawnAmount) {
        require(asset_ == address(asset), "unexpected asset");

        uint256 requesterBalance = aToken.balanceOf(msg.sender);
        uint256 poolLiquidity = asset.balanceOf(address(this));
        withdrawnAmount = amount;
        if (withdrawnAmount > requesterBalance) {
            withdrawnAmount = requesterBalance;
        }
        if (withdrawnAmount > poolLiquidity) {
            withdrawnAmount = poolLiquidity;
        }

        if (withdrawnAmount != 0) {
            aToken.burn(msg.sender, withdrawnAmount);
            asset.safeTransfer(to, withdrawnAmount);
        }
    }

    function accrueYield(address user, uint256 amount) external {
        MockUSDC(address(asset)).mint(address(this), amount);
        aToken.mint(user, amount);
    }

    function drainLiquidity(address receiver, uint256 amount) external {
        asset.safeTransfer(receiver, amount);
    }
}
