// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock as MockERC20 } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import { SparkVault } from "src/SparkVault.sol";

contract HandlerBase is Test {

    uint256 constant RAY = 1e27;

    uint256 public MAX_AMOUNT;

    MockERC20  asset;
    SparkVault vault;

    modifier totalAssetsCheck() {
        uint256 totalAssets = vault.totalAssets();
        _;
        assertGe(vault.totalAssets(), totalAssets);
    }

    modifier accountingCheck() {
        uint256 convertToAssets = vault.convertToAssets(1e18);
        _;
        assertGe(vault.convertToAssets(1e18), convertToAssets);
    }

    constructor(address _vault) {
        vault = SparkVault(_vault);
        asset = MockERC20(vault.asset());

        MAX_AMOUNT = 10_000_000_000 * 10 ** asset.decimals();
    }

}
