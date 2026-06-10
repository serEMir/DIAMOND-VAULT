// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockAToken
 * @notice Small Aave-shaped receipt token used to test the Aave strategy facet locally.
 */
contract MockAToken is ERC20 {
    uint8 private immutable _tokenDecimals;
    address public immutable pool;
    address private immutable _underlyingAsset;

    error MockAToken__OnlyPool();

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address pool_, address underlyingAsset_)
        ERC20(name_, symbol_)
    {
        _tokenDecimals = decimals_;
        pool = pool_;
        _underlyingAsset = underlyingAsset_;
    }

    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }

    function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
        return _underlyingAsset;
    }

    function POOL() external view returns (address) {
        return pool;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != pool) revert MockAToken__OnlyPool();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (msg.sender != pool) revert MockAToken__OnlyPool();
        _burn(from, amount);
    }
}
