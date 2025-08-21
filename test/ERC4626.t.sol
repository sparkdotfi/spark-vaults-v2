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

    function setUp() public virtual override(ERC4626Test, SparkVaultTestBase) {
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

}

contract SparkVaultERC4626Test is SparkVaultTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    event Referral(uint16 indexed referral, address indexed owner, uint256 assets, uint256 shares);

    // Do a deposit to get non-zero state
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

    function test_depositWithReferral() public {
        uint16 referral = 1;

        uint256 assets = 1_000_000e6;
        uint256 shares = vault.previewDeposit(assets);

        assertEq(shares, 999_892.551764e6);

        deal(address(asset), user2, assets);

        assertEq(vault.balanceOf(user3),          0);
        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(asset.balanceOf(user2),          assets);
        assertEq(asset.balanceOf(address(vault)), 1_000_000e6);

        vm.startPrank(user2);

        asset.approve(address(vault), assets);

        vm.expectEmit(true, true, false, true, address(vault));
        emit Referral(referral, user3, assets, shares);
        vault.deposit(assets, user3, referral);

        vm.stopPrank();

        assertEq(vault.balanceOf(user3),          shares);
        assertEq(vault.totalSupply(),             1_000_000e6 + shares);
        assertEq(asset.balanceOf(user2),          0);
        assertEq(asset.balanceOf(address(vault)), 1_000_000e6 + assets);
    }

    function test_mintWithReferral() public {
        uint16 referral = 1;

        uint256 shares = 1_000_000e6;
        uint256 assets = vault.previewMint(shares);

        assertEq(assets, 1_000_107.459783e6);

        deal(address(asset), user2, assets);

        assertEq(vault.balanceOf(user3),          0);
        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(asset.balanceOf(user2),          assets);
        assertEq(asset.balanceOf(address(vault)), 1_000_000e6);

        vm.startPrank(user2);

        asset.approve(address(vault), assets);

        vm.expectEmit(true, true, false, true, address(vault));
        emit Referral(referral, user3, assets, shares);
        vault.mint(shares, user3, referral);

        vm.stopPrank();

        assertEq(vault.balanceOf(user3),          shares);
        assertEq(vault.totalSupply(),             1_000_000e6 + shares);
        assertEq(asset.balanceOf(user2),          0);
        assertEq(asset.balanceOf(address(vault)), 1_000_000e6 + assets);
    }

}

contract SparkVaultDepositFailureTests is SparkVaultTestBase {

    function test_deposit_revertsReceiverZeroAddress() public {
        uint256 amount = 1_000_000e6;
        vm.expectRevert("SparkVault/invalid-address");
        vault.deposit(amount, address(0));
    }

    function test_deposit_revertsReceiverVault() public {
        uint256 amount = 1_000_000e6;
        vm.expectRevert("SparkVault/invalid-address");
        vault.deposit(amount, address(vault));
    }

}

contract SparkVaultDepositSuccessTests is SparkVaultTestBase {

    address user1 = makeAddr("user1");

    function setUp() public override {
        super.setUp();

        vm.prank(admin);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);

        vm.prank(setter);
        vault.setSsr(FOUR_PCT_SSR);
    }

    function test_deposit() public {
        uint256 amount = 1_000_000e6;

        deal(address(asset), user1, amount);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          amount);

        vm.startPrank(user1);
        asset.approve(address(vault), amount);
        vault.deposit(amount, user1);
        vm.stopPrank();

        assertEq(vault.totalSupply(),             amount);
        assertEq(vault.balanceOf(user1),          amount);
        assertEq(vault.assetsOf(user1),           amount);
        assertEq(vault.totalAssets(),             amount);
        assertEq(asset.balanceOf(address(vault)), amount);
        assertEq(asset.balanceOf(user1),          0);
    }

}

contract SparkVaultMintFailureTests is SparkVaultTestBase {

    function test_mint_revertsReceiverZeroAddress() public {
        uint256 shares = 1_000_000e6;
        vm.expectRevert("SparkVault/invalid-address");
        vault.mint(shares, address(0));
    }

    function test_deposit_revertsReceiverVault() public {
        uint256 shares = 1_000_000e6;
        vm.expectRevert("SparkVault/invalid-address");
        vault.mint(shares, address(vault));
    }

}

contract SparkVaultMintSuccessTests is SparkVaultTestBase {

    address user1 = makeAddr("user1");

    function setUp() public override {
        super.setUp();

        vm.prank(admin);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);

        vm.prank(setter);
        vault.setSsr(FOUR_PCT_SSR);
    }

    function test_mint() public {
        uint256 amount = 1_000_000e6;

        deal(address(asset), user1, amount);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          amount);

        vm.startPrank(user1);
        asset.approve(address(vault), amount);
        vault.mint(amount, user1);
        vm.stopPrank();

        assertEq(vault.totalSupply(),             amount);
        assertEq(vault.balanceOf(user1),          amount);
        assertEq(vault.assetsOf(user1),           amount);
        assertEq(vault.totalAssets(),             amount);
        assertEq(asset.balanceOf(address(vault)), amount);
        assertEq(asset.balanceOf(user1),          0);
    }

}

contract SparkVaultWithdrawFailureTests is SparkVaultTestBase {

    address user1 = makeAddr("user1");

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

    function test_withdraw_revertsInsufficientBalanceBoundary() public {
        uint256 assets = vault.assetsOf(user1);

        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), assets);

        // Withdraw more than assets should revert
        vm.prank(user1);
        vm.expectRevert("SparkVault/insufficient-balance");
        vault.withdraw(assets + 1, user1, user1);

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          1_000_000e6);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        // Withdrawing assets should succeed
        vm.prank(user1);
        vault.withdraw(assets, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

    function test_withdraw_revertsInsufficientAllowanceBoundary() public {
        uint256 assets = vault.assetsOf(user1);

        address randomUser = makeAddr("randomUser");

        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), assets);

        vm.prank(randomUser);
        vm.expectRevert("SparkVault/insufficient-allowance");
        vault.withdraw(assets, user1, user1);

        vm.prank(user1);
        vault.approve(randomUser, assets);

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          1_000_000e6);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        vm.prank(randomUser);
        vault.withdraw(assets, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

}

contract SparkVaultWithdrawSuccessTests is SparkVaultTestBase {

    address user1 = makeAddr("user1");

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

    function test_withdraw() public {
        uint256 assets = vault.assetsOf(user1);

        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), 1_000_107.459782e6);

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          1_000_000e6);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        vm.prank(user1);
        vault.withdraw(assets, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

    function test_withdraw_msgSenderNotOwner() public {
        address random = makeAddr("random");

        uint256 assets = vault.assetsOf(user1);

        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), 1_000_107.459782e6);

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          1_000_000e6);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        vm.prank(user1);
        vault.approve(random, 1_000_000e6);

        vm.prank(random);
        vault.withdraw(assets, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

}

contract SparkVaultRedeemFailureTests is SparkVaultTestBase {

    address user1 = makeAddr("user1");

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

    function test_redeem_revertsInsufficientBalanceBoundary() public {
        uint256 shares = vault.balanceOf(user1);
        uint256 assets = vault.assetsOf(user1);

        assertEq(shares, 1_000_000e6);
        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), assets);

        // Redeem more than shares should revert
        vm.prank(user1);
        vm.expectRevert("SparkVault/insufficient-balance");
        vault.redeem(shares + 1, user1, user1);

        // Redeeming shares should succeed
        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          shares);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        vm.prank(user1);
        vault.redeem(shares, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

    function test_redeem_revertsInsufficientAllowanceBoundary() public {
        uint256 shares = vault.balanceOf(user1);
        uint256 assets = vault.assetsOf(user1);

        address randomUser = makeAddr("randomUser");

        assertEq(shares, 1_000_000e6);
        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), assets);

        vm.prank(randomUser);
        vm.expectRevert("SparkVault/insufficient-allowance");
        vault.redeem(shares, user1, user1);

        vm.prank(user1);
        vault.approve(randomUser, shares);

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          shares);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        vm.prank(randomUser);
        vault.redeem(shares, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

}

contract SparkVaultRedeemSuccessTests is SparkVaultTestBase {

    address user1 = makeAddr("user1");

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

    function test_redeem() public {
        uint256 shares = vault.balanceOf(user1);
        uint256 assets = vault.assetsOf(user1);

        assertEq(shares, 1_000_000e6);
        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), 1_000_107.459782e6);

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          shares);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        vm.prank(user1);
        vault.redeem(shares, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

    function test_redeem_msgSenderNotOwner() public {
        address random = makeAddr("random");

        uint256 shares = vault.balanceOf(user1);
        uint256 assets = vault.assetsOf(user1);

        assertEq(shares, 1_000_000e6);
        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(vault), 1_000_107.459782e6);

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          1_000_000e6);
        assertEq(vault.assetsOf(user1),           assets);
        assertEq(vault.totalAssets(),             assets);
        assertEq(asset.balanceOf(address(vault)), assets);
        assertEq(asset.balanceOf(user1),          0);

        vm.prank(user1);
        vault.approve(random, 1_000_000e6);

        vm.prank(random);
        vault.redeem(shares, user1, user1);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          assets);
    }

}
