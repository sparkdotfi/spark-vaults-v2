// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "../TestBase.t.sol";

contract SparkBoostedVaultDepositTest is SparkBoostedVaultTestBase {

    event Drip(uint256 chi, uint256 diff);
    event Deposit(address indexed owner, uint256 assets, uint256 shares, uint64 depositTime);
    event Referral(uint16 indexed referral, address indexed owner, uint256 assets, uint256 shares);

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    /**********************************************************************************************/
    /*** deposit Tests                                                                          ***/
    /**********************************************************************************************/

    function test_deposit_revertsTakerCannotDeposit() external {
        deal(address(asset), taker, 1_000e6);

        vm.startPrank(taker);

        asset.approve(address(vault), 1_000e6);

        vm.expectRevert("SparkBoostedVault/taker-cannot-deposit");
        vault.deposit(1_000e6);

        vm.stopPrank();
    }

    function test_deposit_revertsExistingPosition() external {
        _deposit(user1, 100_000e6);

        deal(address(asset), user1, 100_000e6);

        vm.startPrank(user1);

        asset.approve(address(vault), 100_000e6);

        vm.expectRevert("SparkBoostedVault/existing-position");
        vault.deposit(100_000e6);

        vm.stopPrank();
    }

    function test_deposit_depositCapExceededBoundary() external {
        deal(address(asset), user1, 1_000_000e6 + 1);

        vm.startPrank(user1);

        asset.approve(address(vault), 1_000_000e6 + 1);

        vm.expectRevert("SparkBoostedVault/deposit-cap-exceeded");
        vault.deposit(1_000_000e6 + 1);

        vault.deposit(1_000_000e6);  // exactly the cap is allowed

        vm.stopPrank();
    }

    function test_deposit() external {
        uint256 amount = 100_000e6;
        uint64  t0     = uint64(block.timestamp);

        deal(address(asset), user1, amount);

        assertEq(asset.balanceOf(user1),          amount);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(vault.totalShares(),             0);
        assertEq(vault.totalPrincipal(),          0);

        vm.startPrank(user1);

        asset.approve(address(vault), amount);

        vm.expectEmit(address(vault));
        emit Deposit(user1, amount, amount, t0);
        vault.deposit(amount);

        vm.stopPrank();

        assertEq(asset.balanceOf(user1),          0);
        assertEq(asset.balanceOf(address(vault)), amount);
        assertEq(vault.totalShares(),             amount);
        assertEq(vault.totalPrincipal(),          amount);

        (uint256 principal, uint256 shares, uint64 depositTime) = vault.positions(user1);
        assertEq(principal,   amount);
        assertEq(shares,      amount);
        assertEq(depositTime, t0);
    }

    function test_deposit_withReferral() external {
        uint256 amount = 100_000e6;
        uint16  code   = 42;
        uint64  t0     = uint64(block.timestamp);

        deal(address(asset), user1, amount);

        assertEq(asset.balanceOf(user1),          amount);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(vault.totalShares(),             0);
        assertEq(vault.totalPrincipal(),          0);

        vm.startPrank(user1);

        asset.approve(address(vault), amount);

        vm.expectEmit(address(vault));
        emit Referral(code, user1, amount, amount);
        vault.deposit(amount, code);

        vm.stopPrank();

        assertEq(asset.balanceOf(user1),          0);
        assertEq(asset.balanceOf(address(vault)), amount);
        assertEq(vault.totalShares(),             amount);
        assertEq(vault.totalPrincipal(),          amount);

        (uint256 principal, uint256 shares, uint64 depositTime) = vault.positions(user1);
        assertEq(principal,   amount);
        assertEq(shares,      amount);
        assertEq(depositTime, t0);
    }

    function test_deposit_multipleUsers() external {
        _deposit(user1, 100_000e6);
        _deposit(user2, 200_000e6);

        assertEq(vault.totalShares(),    300_000e6);
        assertEq(vault.totalPrincipal(), 300_000e6);

        (uint256 principal1, uint256 shares1, ) = vault.positions(user1);
        (uint256 principal2, uint256 shares2, ) = vault.positions(user2);

        assertEq(principal1, 100_000e6);
        assertEq(shares1,    100_000e6);
        assertEq(principal2, 200_000e6);
        assertEq(shares2,    200_000e6);
    }

    /**********************************************************************************************/
    /*** maxDeposit Tests                                                                       ***/
    /**********************************************************************************************/

    function test_maxDeposit() external {
        assertEq(vault.maxDeposit(taker), 0);            // taker: always zero
        assertEq(vault.maxDeposit(user1), 1_000_000e6);  // full remaining cap

        _deposit(user1, 100_000e6);

        assertEq(vault.maxDeposit(user1), 0);          // user with open position: zero
        assertEq(vault.maxDeposit(user2), 900_000e6);  // cap minus totalAssets
    }

    /**********************************************************************************************/
    /*** previewDeposit Tests                                                                   ***/
    /**********************************************************************************************/

    function test_previewDeposit() external view {
        assertEq(vault.previewDeposit(100_000e6), 100_000e6);
        assertEq(vault.previewDeposit(1),         1);
    }

}
