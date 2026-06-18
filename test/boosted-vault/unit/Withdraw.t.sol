// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "../TestBase.t.sol";

contract SparkBoostedVaultWithdrawTest is SparkBoostedVaultTestBase {

    event Drip(uint256 chi, uint256 diff);
    event Withdraw(address indexed owner, uint256 assets, uint256 shares);

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    /**********************************************************************************************/
    /*** withdraw Tests                                                                         ***/
    /**********************************************************************************************/

    function test_withdraw_zeroPosition() external {
        vm.expectRevert("SparkBoostedVault/zero-position");
        vm.prank(user1);
        vault.withdraw();
    }

    function test_withdraw_beforeCliff() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(CLIFF - 1);

        _fundVaultToTotalAssets();

        assertEq(vault.vestingMultiplier(user1), 0);
        assertEq(vault.vestedYieldOf(user1),     0);
        assertEq(vault.withdrawableOf(user1),    amount);

        assertEq(asset.balanceOf(user1), 0);
        assertEq(vault.totalShares(),    amount);
        assertEq(vault.totalPrincipal(), amount);

        vm.prank(user1);
        vault.withdraw();

        assertEq(asset.balanceOf(user1), amount);
        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        (uint256 principal, uint256 shares, uint64 depositTime) = vault.positions(user1);
        assertEq(principal,   0);
        assertEq(shares,      0);
        assertEq(depositTime, 0);
    }

    function test_withdraw_atCliff() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        // Exactly at cliff, multiplier jumps from 0 to (CLIFF/TERM)^2
        skip(CLIFF);

        _fundVaultToTotalAssets();

        uint256 multiplier     = vault.vestingMultiplier(user1);
        uint256 rawAssets      = vault.assetsOf(user1);
        uint256 rawYield       = rawAssets - amount;
        uint256 expectedVested = rawYield * multiplier / RAY;

        uint256 expectedMultiplierAtCliff = uint256(CLIFF) * uint256(CLIFF) * RAY / (uint256(TERM) * uint256(TERM));

        assertEq(multiplier,     expectedMultiplierAtCliff);
        assertGt(expectedVested, 0);

        assertEq(asset.balanceOf(user1), 0);

        vm.prank(user1);
        vault.withdraw();

        assertEq(asset.balanceOf(user1), amount + expectedVested);
    }

    function test_withdraw_duringVesting() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(180 days);

        _fundVaultToTotalAssets();

        uint256 multiplier     = vault.vestingMultiplier(user1);
        uint256 rawAssets      = vault.assetsOf(user1);
        uint256 rawYield       = rawAssets - amount;
        uint256 expectedVested = rawYield * multiplier / RAY;

        uint256 expectedMultiplier = uint256(180 days) * uint256(180 days) * RAY / (uint256(TERM) * uint256(TERM));

        assertEq(multiplier, expectedMultiplier);

        assertEq(asset.balanceOf(user1), 0);

        vm.prank(user1);
        vault.withdraw();

        assertEq(asset.balanceOf(user1), amount + expectedVested);
    }

    function test_withdraw_afterTerm() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(TERM);

        _fundVaultToTotalAssets();

        assertEq(vault.vestingMultiplier(user1), RAY);

        uint256 expectedChi = vault.nowChi();
        uint256 rawAssets   = vault.assetsOf(user1);
        uint256 rawYield    = rawAssets - amount;

        assertGt(rawAssets, amount);

        vm.expectEmit(address(vault));
        emit Drip(expectedChi, rawYield);
        emit Withdraw(user1, rawAssets, amount);
        vm.prank(user1);
        vault.withdraw();

        assertEq(asset.balanceOf(user1),         rawAssets);
        assertEq(vault.totalShares(),            0);
        assertEq(vault.totalPrincipal(),         0);

        (uint256 principal, uint256 shares, ) = vault.positions(user1);
        assertEq(principal, 0);
        assertEq(shares,    0);
    }

    function test_withdraw_forfeitsUnvestedYield() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(CLIFF - 1);  // before cliff: all accrued yield is unvested

        _fundVaultToTotalAssets();

        uint256 unvestedYield = vault.unvestedYieldOf(user1);

        assertGt(unvestedYield, 0);

        assertEq(asset.balanceOf(user1),          0);
        assertEq(asset.balanceOf(address(vault)), amount + unvestedYield);

        vm.prank(user1);
        vault.withdraw();

        assertEq(asset.balanceOf(user1),          amount);
        assertEq(asset.balanceOf(address(vault)), unvestedYield);
        assertEq(vault.totalShares(),             0);
        assertEq(vault.totalAssets(),             0);

        assertEq(asset.balanceOf(taker),          0);
        assertEq(asset.balanceOf(address(vault)), unvestedYield);

        // TAKER claims the forfeited yield.
        vm.prank(taker);
        vault.take(unvestedYield);

        assertEq(asset.balanceOf(taker),          unvestedYield);
        assertEq(asset.balanceOf(address(vault)), 0);
    }

    /**********************************************************************************************/
    /*** maxWithdraw Tests                                                                      ***/
    /**********************************************************************************************/

    function test_maxWithdraw() external {
        assertEq(vault.maxWithdraw(user1), 0);  // no position

        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(TERM);

        // Vault has only the deposited assets, not the accrued yield.
        assertEq(vault.maxWithdraw(user1), amount);

        // After funding to cover yield: maxWithdraw equals full withdrawable.
        _fundVaultToTotalAssets();

        assertEq(vault.maxWithdraw(user1), vault.withdrawableOf(user1));
    }

}
