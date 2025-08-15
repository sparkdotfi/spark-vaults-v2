// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./TestBase.t.sol";

contract ValueAccrualE2ETest is VaultUnitTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    struct TestState {
        uint256 assetUser1Balance;
        uint256 assetUser2Balance;
        uint256 assetVaultBalance;
        uint256 assetTakerBalance;

        uint256 vaultTotalAssets;
        uint256 vaultTotalSupply;
        uint256 vaultUser1Assets;
        uint256 vaultUser1Balance;
        uint256 vaultUser2Assets;
        uint256 vaultUser2Balance;
    }

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);
        vm.stopPrank();
    }

    function test_e2e_valueAccrual() public {
        deal(address(usdc), user1, 1_000_000e6);
        deal(address(usdc), user2, 1_000_000e6);

        TestState memory state;

        // Leave the rest of the struct as zeros
        state.assetUser1Balance = 1_000_000e6;
        state.assetUser2Balance = 1_000_000e6;

        _assertTestState(state);

        // Step 1: User 1 deposits 1M assets

        vm.startPrank(user1);
        usdc.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, user1);
        vm.stopPrank();

        state.assetUser1Balance = 0;
        state.assetVaultBalance = 1_000_000e6;
        state.vaultTotalAssets  = 1_000_000e6;
        state.vaultTotalSupply  = 1_000_000e6;
        state.vaultUser1Assets  = 1_000_000e6;
        state.vaultUser1Balance = 1_000_000e6;

        _assertTestState(state);

        // Step 2: Taker withdraws 1M assets

        vm.startPrank(taker);
        vault.take(1_000_000e6);
        vm.stopPrank();

        // No vault accounting changes
        state.assetTakerBalance = 1_000_000e6;
        state.assetVaultBalance = 0;

        _assertTestState(state);

        // Step 3: Setter increases SSR

        vm.startPrank(setter);
        vault.setSsr(FOUR_PCT_SSR);
        vm.stopPrank();

        // No vault accounting changes
        _assertTestState(state);

        // Step 4: Warp a year

        skip(365 days);

        state.vaultTotalAssets = 1_040_000e6 - 1;  // Rounding error gets introduced (4% APY)
        state.vaultUser1Assets = 1_040_000e6 - 1;  // Rounding error gets introduced (4% APY)

        _assertTestState(state);

        // Step 5: User 2 deposits 1M assets

        vm.startPrank(user2);
        usdc.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, user2);
        vm.stopPrank();

        state.vaultUser2Balance = 1_000_000e6 * uint256(1_000_000e6) / (1_040_000e6 - 1) - 1;

        assertEq(state.vaultUser2Balance, 961_538.461538e6);

        state.assetUser2Balance = 0;
        state.assetVaultBalance = 1_000_000e6;
        state.vaultTotalAssets  = 2_040_000e6 - 1;
        state.vaultTotalSupply  = 1_000_000e6 + state.vaultUser2Balance;
        state.vaultUser2Assets  = 1_000_000e6 - 1;

        _assertTestState(state);

        // Step 6: Taker withdraws 1M assets

        vm.startPrank(taker);
        vault.take(1_000_000e6);
        vm.stopPrank();

        state.assetTakerBalance = 2_000_000e6;
        state.assetVaultBalance = 0;

        _assertTestState(state);

        // Step 7: Setter decreases SSR

        vm.startPrank(setter);
        vault.setSsr(ONE_PCT_SSR);
        vm.stopPrank();

        // No vault accounting changes
        _assertTestState(state);

        // Step 8: Warp a year

        skip(365 days);

        state.vaultTotalAssets += state.vaultTotalAssets * 0.01e27 / 1e27 + 1;  // 1% APY
        state.vaultUser1Assets += state.vaultUser1Assets * 0.01e27 / 1e27 + 1;  // 1% APY
        state.vaultUser2Assets += state.vaultUser2Assets * 0.01e27 / 1e27 + 1;  // 1% APY

        assertEq(state.vaultTotalAssets, 2_060_400e6 - 1);
        assertEq(state.vaultUser1Assets, 1_050_400e6 - 1);  // 1% APY on 1.04m
        assertEq(state.vaultUser2Assets, 1_010_000e6 - 1);  // 1% APY on new deposit

        _assertTestState(state);

        // Step 9: Taker adds some funds back with yield

        deal(address(usdc), taker, 1_200_000e6);
        vm.prank(taker);
        usdc.transfer(address(vault), 1_200_000e6);

        state.assetTakerBalance = 0;  // Deal sets balance to 1.2m
        state.assetVaultBalance = 1_200_000e6;

        _assertTestState(state);

        // Step 10: User 1 withdraws full position

        vm.startPrank(user1);
        vault.redeem(vault.balanceOf(user1), user1, user1);
        vm.stopPrank();

        state.assetUser1Balance += 1_050_400e6 - 1;
        state.assetVaultBalance -= 1_050_400e6 - 1;

        state.vaultUser1Balance = 0;
        state.vaultUser1Assets  = 0;

        state.vaultTotalAssets -= 1_050_400e6;
        state.vaultTotalSupply -= 1_000_000e6;

        _assertTestState(state);

        // Step 11: Show that user 2 can't access their full position, but can access some

        uint256 maxWithdraw = vault.maxWithdraw(user2);

        assertEq(maxWithdraw, usdc.balanceOf(address(vault)));
        assertEq(maxWithdraw, 149_600e6 + 1);  // 1.2m cash minus User 1 withdrawal

        assertEq(vault.assetsOf(user2), 1_010_000e6 - 1);

        vm.startPrank(user2);
        vm.expectRevert("Vault/insufficient-liquidity");
        vault.withdraw(maxWithdraw + 1, user2, user2);

        vault.withdraw(maxWithdraw, user2, user2);

        vm.stopPrank();

        // NOTE: Skipping state assertions, will add for the final state after full withdrawal

        // Step 12: Taker adds remaining funds back and User 2 withdraws full position

        uint256 outstandingCash = vault.totalAssets() - usdc.balanceOf(address(vault));

        assertEq(outstandingCash, 1_010_000e6 - usdc.balanceOf(address(user2)) - 2);  // Equals remaining amount of User 2's position
        assertEq(outstandingCash, vault.assetsOf(user2));

        deal(address(usdc), taker, outstandingCash);
        vm.prank(taker);
        usdc.transfer(address(vault), outstandingCash);

        vm.startPrank(user2);
        vault.redeem(vault.balanceOf(user2), user2, user2);

        state.assetUser1Balance = 1_050_400e6 - 1;
        state.assetUser2Balance = 1_010_000e6 - 2;
        state.assetVaultBalance = 0;
        state.assetTakerBalance = 0;

        state.vaultTotalAssets  = 0;
        state.vaultTotalSupply  = 0;
        state.vaultUser1Assets  = 0;
        state.vaultUser1Balance = 0;
        state.vaultUser2Assets  = 0;
        state.vaultUser2Balance = 0;

        _assertTestState(state);
    }

    function _assertTestState(TestState memory state, uint256 tolerance) internal {
        assertEq(usdc.balanceOf(user1),          state.assetUser1Balance, "assetUser1Balance");
        assertEq(usdc.balanceOf(user2),          state.assetUser2Balance, "assetUser2Balance");
        assertEq(usdc.balanceOf(address(vault)), state.assetVaultBalance, "assetVaultBalance");
        assertEq(usdc.balanceOf(taker),          state.assetTakerBalance, "assetTakerBalance");

        assertApproxEqAbs(vault.totalAssets(),    state.vaultTotalAssets,  tolerance, "vaultTotalAssets");
        assertApproxEqAbs(vault.totalSupply(),    state.vaultTotalSupply,  tolerance, "vaultTotalSupply");
        assertApproxEqAbs(vault.assetsOf(user1),  state.vaultUser1Assets,  tolerance, "vaultUser1Assets");
        assertApproxEqAbs(vault.balanceOf(user1), state.vaultUser1Balance, tolerance, "vaultUser1Balance");
        assertApproxEqAbs(vault.assetsOf(user2),  state.vaultUser2Assets,  tolerance, "vaultUser2Assets");
        assertApproxEqAbs(vault.balanceOf(user2), state.vaultUser2Balance, tolerance, "vaultUser2Balance");
    }

    function _assertTestState(TestState memory state) internal {
        _assertTestState(state, 0);
    }

}
