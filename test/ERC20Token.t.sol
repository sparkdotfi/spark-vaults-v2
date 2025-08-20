// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { TokenFuzzChecks } from "lib/token-tests/src/TokenFuzzChecks.sol";

import "./TestBase.t.sol";

contract ERC20TokenTests is SparkVaultTestBase, TokenFuzzChecks {

    function setUp() public override {
        super.setUp();
        vm.startPrank(admin);
        vault.setSsrBounds(1e27, vault.MAX_SSR());
        vm.stopPrank();
    }

    function testERC20() public {
        checkBulkERC20(address(vault), "SparkVault", "Spark Savings USDC V2", "spUSDC", "1", 18);
    }

    function testERC20Fuzz(uint256 amount1, uint256 amount2, uint256 ssr, uint256 warpTime) public {
        amount1  = bound(amount1,  0,    1e36);
        amount2  = bound(amount2,  0,    1e36);
        ssr      = bound(ssr,      1e27, 1.000000012857214317438491659e27);  // 0 to 50% APY
        warpTime = bound(warpTime, 0,    10 days);

        vm.prank(setter);
        vault.setSsr(ssr);

        skip(warpTime);

        checkBulkERC20Fuzz({
            _token        : address(vault),
            _contractName : "SparkVault",
            from          : makeAddr("from"),
            to            : makeAddr("to"),
            amount1       : amount1,
            amount2       : amount2
        });
    }

    function testPermit() public {
        checkBulkPermit(address(vault), "SparkVault");
    }

    function testPermitFuzz(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        uint128 privateKey
    )
        public
    {
        amount     = bound(amount,   0,               1e36);
        deadline   = bound(deadline, block.timestamp, block.timestamp + 100 days);
        nonce      = bound(nonce,    0,               type(uint256).max);

        checkBulkPermitFuzz({
            _token        : address(vault),
            _contractName : "SparkVault",
            privKey       : privateKey,
            to            : makeAddr("to"),
            amount        : amount,
            deadline      : deadline,
            nonce         : nonce
        });
    }

}

contract SparkVaultMintFailureTests is SparkVaultTestBase {

    function test_mint_revertsReceiverZeroAddress() public {
        uint256 amount = 1_000_000e6;
        vm.expectRevert("SparkVault/invalid-address");
        vault.deposit(amount, address(0));
    }

    function test_mint_revertsReceiverVault() public {
        uint256 amount = 1_000_000e6;
        vm.expectRevert("SparkVault/invalid-address");
        vault.deposit(amount, address(vault));
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
        deal(address(asset), user1, 1_000_000e6);

        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(user1),          0);
        assertEq(vault.assetsOf(user1),           0);
        assertEq(vault.totalAssets(),             0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(user1),          1_000_000e6);

        vm.startPrank(user1);
        asset.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, user1);
        vm.stopPrank();

        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(user1),          1_000_000e6);
        assertEq(vault.assetsOf(user1),           1_000_000e6);
        assertEq(vault.totalAssets(),             1_000_000e6);
        assertEq(asset.balanceOf(address(vault)), 1_000_000e6);
        assertEq(asset.balanceOf(user1),          0);
    }

}

contract SparkVaultBurntFailureTests is SparkVaultTestBase {

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

    function test_burn_revertsInsufficientBalance() public {
        uint256 assets = vault.assetsOf(user1);

        assertEq(assets, 1_000_107.459782e6);

        vm.prank(user1);
        vm.expectRevert("SparkVault/insufficient-balance");
        vault.withdraw(assets + 1, user1, user1);
    }

    function test_burn_revertsInsufficientAllowance() public {
        uint256 assets = vault.assetsOf(user1);

        assertEq(assets, 1_000_107.459782e6);

        vm.prank(makeAddr("random"));
        vm.expectRevert("SparkVault/insufficient-allowance");
        vault.withdraw(assets, user1, user1);
    }

}

contract SparkVaultBurnSuccessTests is SparkVaultTestBase {

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

    function test_burn() public {
        uint256 assets = vault.assetsOf(user1);

        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(this), 107.459782e6);
        asset.transfer(address(vault), 107.459782e6);

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

    function test_burn_msgSenderNotOwner() public {
        address random = makeAddr("random");

        uint256 assets = vault.assetsOf(user1);

        assertEq(assets, 1_000_107.459782e6);

        // Deal value accrued to the vault
        deal(address(asset), address(this), 107.459782e6);
        asset.transfer(address(vault), 107.459782e6);

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
