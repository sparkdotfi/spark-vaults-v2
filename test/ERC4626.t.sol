// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.29;

import { ERC4626Test, IMockERC20 } from "erc4626-tests/ERC4626.test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SparkVault } from "src/SparkVault.sol";

import { SparkVaultTestBase } from "./TestBase.t.sol";

contract SparkVaultERC4626StandardTest is ERC4626Test, SparkVaultTestBase {

    // NOTE: This cannot be part of SparkVaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant internal RAY = 1e27;

    function setUp() public override(ERC4626Test, SparkVaultTestBase) {
        super.setUp();

        vm.startPrank(admin);
        vault.setSsrBounds(
            1e27, // minSsr
            vault.MAX_SSR() // maxSsr
        );
        vm.stopPrank();

        // >> Set ssr, warp time and drip
        vm.prank(setter);
        // 5% APY:
        // ❯ bc -l <<< 'scale=27; e( l(1.05)/(60 * 60 * 24 * 365) )'
        // 1.000000001547125957863212448
        vault.setSsr(1.000000001547125957863212448e27);
        vm.warp(100 days);
        vault.drip();

        // chi should increase
        assertGt(vault.chi(), RAY);

        // Initialize the ERC4626 test
        _underlying_     = address(asset);
        _vault_          = address(vault);
        _delta_          = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }

    // Set up initial vault state
    function setUpVault(Init memory init) public override {
        // Make assumptions about init
        for (uint256 i = 0; i < N; i++) {
            init.share[i] = _bound(init.share[i], 0, 1_000_000_000e18 - 1);
            init.share[i] = _bound(init.asset[i], 0, 1_000_000_000e18 - 1);
            vm.assume(init.user[i] != address(0) && init.user[i] != address(vault));
        }
        // Call the parent to set up the vault
        super.setUpVault(init);
    }

    // Set up initial yield
    function setUpYield(Init memory init) public override {
        vm.assume(init.yield >= 0);
        init.yield = _bound(init.yield, 0, 1_000_000_000e18 - 1);

        uint256 supply = vault.totalSupply();

        if (supply > 0) {
            uint256 newChi = vault.chi() + uint256(init.yield) * RAY / supply;
            uint256 chiRho = (newChi << 64) + block.timestamp;
            // Directly store chi and rho in storage
            // They are currently packed together at slot #3 in storage
            vm.store(
                address(vault),
                bytes32(uint256(3)),
                bytes32(chiRho)
            );
            assertEq(uint256(vault.rho()), block.timestamp);
            assertEq(uint256(vault.chi()), newChi);
        }
    }

    function test_maxRedeem_liquidityLessThanAmount(Init memory init) public {
        setUpVault(init);
        address caller = init.user[0];
        address owner  = init.user[1];

        // Remove all liquidity from the vault
        vm.startPrank(taker);
        vault.take(IMockERC20(_underlying_).balanceOf(address(vault)));
        vm.stopPrank();

        // Redeem max amount should return 0
        assertEq(vault.maxRedeem(owner), 0);
    }

    function test_maxWithdraw_liquidityLessThanAmount(Init memory init) public {
        setUpVault(init);
        address caller = init.user[0];
        address owner  = init.user[1];

        // Remove all liquidity from the vault
        vm.startPrank(taker);
        vault.take(IMockERC20(_underlying_).balanceOf(address(vault)));
        vm.stopPrank();

        // Withdraw max amount should return 0
        assertEq(vault.maxWithdraw(owner), 0);
    }

    function test_previewWithdraw_revertsOverLiquidityBoundary() public {
        setUpVault(init);
        address caller   = init.user[0];
        address receiver = init.user[1];
        address owner    = init.user[2];
        address other    = init.user[3];
        assets = bound(assets, 1, 1_000_000_000e18 - 1);
        _approve(_vault_, owner, caller, type(uint).max);

        vm.startPrank(taker);
        vault.take(IMockERC20(_underlying_).balanceOf(address(vault)));
        vm.stopPrank();

        vm.expectRevert("Vault/insufficient-liquidity");
        vault.previewWithdraw(assets);
    }

}

contract SparkVaultERC4626Test is SparkVaultTestBase {

    address user1 = makeAddr("user1");

    // Do some deposits to get some non-zero state
    function setUp() public override {
        super.setUp();

        vm.prank(admin);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);

        vm.prank(setter);
        vault.setSsr(FOUR_PCT_SSR);

        deal(address(asset), user1, 1_000_000e6);

        vm.startPrank(user1);
        asset.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, user1);
        vm.stopPrank();

        skip(1 days);
    }

    function test_previewRedeem_revertsOverLiquidityBoundary() public {
        // Deal value accrued to the vault
        deal(address(asset), address(this), 107.459782e6);
        asset.transfer(address(vault), 107.459782e6);

        uint256 shares = vault.balanceOf(user1);

        // Take 1 wei of liquidity from the vault
        vm.prank(taker);
        vault.take(1);

        // Redeem should revert over the liquidity boundary
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vault.previewRedeem(shares);

        // Transfer 1 wei of liquidity back to the vault
        vm.prank(taker);
        asset.transfer(address(vault), 1);

        // Redeem should now succeed
        vault.previewRedeem(shares);
    }

}
