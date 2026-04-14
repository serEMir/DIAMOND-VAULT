// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title MockUSDC
 * @notice Simple mintable ERC-20 mock with 6 decimals for vault and strategy tests.
 */
contract MockUSDC is IERC20Metadata {
    /**
     * @notice ERC-20 token name exposed by the mock.
     */
    string public constant override name = "Mock USDC";

    /**
     * @notice ERC-20 token symbol exposed by the mock.
     */
    string public constant override symbol = "mUSDC";

    /**
     * @notice ERC-20 decimals exposed by the mock.
     */
    uint8 public constant override decimals = 6;

    /**
     * @notice Total minted token supply.
     */
    uint256 public override totalSupply;

    /**
     * @notice Account balances tracked by the mock token.
     */
    mapping(address => uint256) public override balanceOf;

    /**
     * @notice Allowances tracked by the mock token.
     */
    mapping(address => mapping(address => uint256)) public override allowance;

    /**
     * @notice Mints tokens to an account.
     * @param to The account that will receive the minted tokens.
     * @param amount The amount to mint.
     */
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Sets an allowance for a spender.
     * @param spender The account allowed to spend the caller's tokens.
     * @param value The allowance amount to set.
     * @return True after the approval is stored.
     */
    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice Transfers tokens to another account.
     * @param to The recipient of the tokens.
     * @param value The amount to transfer.
     * @return True after the transfer succeeds.
     */
    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice Transfers tokens using an existing allowance.
     * @param from The account to transfer tokens from.
     * @param to The recipient of the tokens.
     * @param value The amount to transfer.
     * @return True after the transfer succeeds.
     */
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @notice Moves tokens between accounts.
     * @param from The account to debit.
     * @param to The account to credit.
     * @param value The amount to move.
     */
    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
