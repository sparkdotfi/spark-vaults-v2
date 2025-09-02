// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "./TestBase.t.sol";

import "forge-std/console2.sol";

contract ValueAccrualE2ETest is SparkVaultTestBase {

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
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);
        vault.setDepositCap(2_100_000e6);
        vm.stopPrank();
    }

    function test_e2e_valueAccrual() public {
        deal(address(asset), user1, 1_000_000e6);
        deal(address(asset), user2, 1_000_000e6);

        TestState memory state;

        // Leave the rest of the struct as zeros
        state.assetUser1Balance = 1_000_000e6;
        state.assetUser2Balance = 1_000_000e6;

        _assertTestState(state);

        // Step 1: User 1 deposits 1M assets

        vm.startPrank(user1);
        asset.approve(address(vault), 1_000_000e6);
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

        // Step 3: Setter increases VSR

        vm.startPrank(setter);
        vault.setVsr(FOUR_PCT_VSR);
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
        asset.approve(address(vault), 1_000_000e6);
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

        // Step 7: Setter decreases VSR

        vm.startPrank(setter);
        vault.setVsr(ONE_PCT_VSR);
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

        deal(address(asset), taker, 1_200_000e6);
        vm.prank(taker);
        asset.transfer(address(vault), 1_200_000e6);

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

        assertEq(maxWithdraw, asset.balanceOf(address(vault)));
        assertEq(maxWithdraw, 149_600e6 + 1);  // 1.2m cash minus User 1 withdrawal

        assertEq(vault.assetsOf(user2), 1_010_000e6 - 1);

        vm.startPrank(user2);
        vm.expectRevert("SparkVault/insufficient-liquidity");
        vault.withdraw(maxWithdraw + 1, user2, user2);

        vault.withdraw(maxWithdraw, user2, user2);

        vm.stopPrank();

        // NOTE: Skipping state assertions, will add for the final state after full withdrawal

        // Step 12: Taker adds remaining funds back and User 2 withdraws full position

        uint256 outstandingCash = vault.totalAssets() - asset.balanceOf(address(vault));

        assertEq(outstandingCash, 1_010_000e6 - asset.balanceOf(address(user2)) - 2);  // Equals remaining amount of User 2's position
        assertEq(outstandingCash, vault.assetsOf(user2));

        deal(address(asset), taker, outstandingCash);
        vm.prank(taker);
        asset.transfer(address(vault), outstandingCash);

        vm.startPrank(user2);
        vault.redeem(vault.balanceOf(user2), user2, user2);

        // Final state
        _assertTestState({
            state: TestState({
                assetUser1Balance : 1_050_400e6 - 1, // 4% APY on 1M, 1% APY on 1.04M
                assetUser2Balance : 1_010_000e6 - 2, // 1% APY on 1M
                assetVaultBalance : 0,
                assetTakerBalance : 0,
                vaultTotalAssets  : 0,
                vaultTotalSupply  : 0,
                vaultUser1Assets  : 0,
                vaultUser1Balance : 0,
                vaultUser2Assets  : 0,
                vaultUser2Balance : 0
            }),
            tolerance: 2
        });
    }

    function testFuzz_e2e_valueAccrual(
        uint256 user1Deposit,
        uint256 user2Deposit,
        uint256 takerWithdrawal1,
        uint256 takerWithdrawal2
    )
        public
    {
        user1Deposit     = _bound(user1Deposit,     1000e6, 1_000_000e6);
        user2Deposit     = _bound(user2Deposit,     1000e6, 1_000_000e6);
        takerWithdrawal1 = _bound(takerWithdrawal1, 1000e6, user1Deposit);
        takerWithdrawal2 = _bound(takerWithdrawal2, 1000e6, user2Deposit);

        deal(address(asset), user1, user1Deposit);
        deal(address(asset), user2, user2Deposit);

        TestState memory state;

        // Leave the rest of the struct as zeros
        state.assetUser1Balance = user1Deposit;
        state.assetUser2Balance = user2Deposit;

        _assertTestState(state, 0);

        // Step 1: User 1 deposits assets

        vm.startPrank(user1);
        asset.approve(address(vault), user1Deposit);
        vault.deposit(user1Deposit, user1);
        vm.stopPrank();

        state.assetUser1Balance = 0;
        state.assetVaultBalance = user1Deposit;
        state.vaultTotalAssets  = user1Deposit;
        state.vaultTotalSupply  = user1Deposit;
        state.vaultUser1Assets  = user1Deposit;
        state.vaultUser1Balance = user1Deposit;

        _assertTestState(state, 0);

        // Step 2: Taker withdraws assets

        takerWithdrawal1 = _bound(takerWithdrawal1, 1, asset.balanceOf(address(vault)));

        vm.startPrank(taker);
        vault.take(takerWithdrawal1);
        vm.stopPrank();

        // No vault accounting changes
        state.assetTakerBalance += takerWithdrawal1;
        state.assetVaultBalance -= takerWithdrawal1;

        _assertTestState(state, 0);

        // Step 3: Setter increases VSR

        vm.startPrank(setter);
        vault.setVsr(FOUR_PCT_VSR);
        vm.stopPrank();

        // No vault accounting changes
        _assertTestState(state, 0);

        // Step 4: Warp a year

        skip(365 days);

        state.vaultTotalAssets += user1Deposit * 0.04e27 / 1e27;  // 4% APY
        state.vaultUser1Assets += user1Deposit * 0.04e27 / 1e27;  // 4% APY

        _assertTestState(state, 1);

        // Step 5: User 2 deposits assets

        vm.startPrank(user2);
        asset.approve(address(vault), user2Deposit);
        vault.deposit(user2Deposit, user2);
        vm.stopPrank();

        uint256 expectedUser2Balance = user2Deposit * uint256(user1Deposit) / (state.vaultTotalAssets);

        state.vaultUser2Balance = user2Deposit * 1e27 / vault.nowChi();  // More precise

        assertApproxEqAbs(state.vaultUser2Balance, expectedUser2Balance, 0.01e6);

        state.assetUser2Balance = 0;

        state.assetVaultBalance += user2Deposit;
        state.vaultTotalAssets  += user2Deposit;
        state.vaultTotalSupply  += state.vaultUser2Balance;
        state.vaultUser2Assets  += user2Deposit;

        _assertTestState(state, 3);

        // Step 6: Taker withdraws more assets

        takerWithdrawal2 = _bound(takerWithdrawal2, 1, asset.balanceOf(address(vault)));

        vm.startPrank(taker);
        vault.take(takerWithdrawal2);
        vm.stopPrank();

        state.assetTakerBalance += takerWithdrawal2;
        state.assetVaultBalance -= takerWithdrawal2;

        _assertTestState(state, 3);

        // Step 7: Setter decreases VSR

        vm.startPrank(setter);
        vault.setVsr(ONE_PCT_VSR);
        vm.stopPrank();

        // No vault accounting changes
        _assertTestState(state, 3);

        // Step 8: Warp a year

        skip(365 days);

        state.vaultTotalAssets += state.vaultTotalAssets * 0.01e27 / 1e27;  // 1% APY
        state.vaultUser1Assets += state.vaultUser1Assets * 0.01e27 / 1e27;  // 1% APY
        state.vaultUser2Assets += state.vaultUser2Assets * 0.01e27 / 1e27;  // 1% APY

        _assertTestState(state, 3);

        // Step 9: Taker adds all funds back with yield

        uint256 outstandingCash = vault.assetsOutstanding();

        deal(address(asset), taker, outstandingCash);
        vm.prank(taker);
        asset.transfer(address(vault), outstandingCash);

        state.assetTakerBalance = 0;
        state.assetVaultBalance += outstandingCash;

        assertEq(state.assetVaultBalance, vault.totalAssets());

        _assertTestState(state, 3);

        // Step 10: User 1 withdraws full position

        vm.startPrank(user1);
        vault.redeem(vault.balanceOf(user1), user1, user1);
        vm.stopPrank();

        state.assetUser1Balance += state.vaultUser1Assets;
        state.assetVaultBalance -= state.vaultUser1Assets;

        state.vaultTotalAssets -= state.vaultUser1Assets;
        state.vaultTotalSupply -= state.vaultUser1Balance;

        state.vaultUser1Balance = 0;
        state.vaultUser1Assets  = 0;

        _assertTestState(state, 3);

        // Step 12: User 2 withdraws full position

        vm.startPrank(user2);
        vault.redeem(vault.balanceOf(user2), user2, user2);

        // Final state
        _assertTestState({
            state: TestState({
                assetUser1Balance : (user1Deposit * 1.04e27 / 1e27) * 1.01e27 / 1e27, // 4% APY on 1M, 1% APY on 1.04M
                assetUser2Balance : user2Deposit * 1.01e27 / 1e27, // 1% APY on 1M
                assetVaultBalance : 0,
                assetTakerBalance : 0,
                vaultTotalAssets  : 0,
                vaultTotalSupply  : 0,
                vaultUser1Assets  : 0,
                vaultUser1Balance : 0,
                vaultUser2Assets  : 0,
                vaultUser2Balance : 0
            }),
            tolerance: 2
        });
    }

    /**********************************************************************************************/
    /*** Internal functions                                                                     ***/
    /**********************************************************************************************/

    function _assertTestState(TestState memory state, uint256 tolerance) internal view {
        assertApproxEqAbs(asset.balanceOf(user1),          state.assetUser1Balance, tolerance, "assetUser1Balance");
        assertApproxEqAbs(asset.balanceOf(user2),          state.assetUser2Balance, tolerance, "assetUser2Balance");
        assertApproxEqAbs(asset.balanceOf(address(vault)), state.assetVaultBalance, tolerance, "assetVaultBalance");
        assertApproxEqAbs(asset.balanceOf(taker),          state.assetTakerBalance, tolerance, "assetTakerBalance");

        assertApproxEqAbs(vault.totalAssets(),    state.vaultTotalAssets,  tolerance, "vaultTotalAssets");
        assertApproxEqAbs(vault.totalSupply(),    state.vaultTotalSupply,  tolerance, "vaultTotalSupply");
        assertApproxEqAbs(vault.assetsOf(user1),  state.vaultUser1Assets,  tolerance, "vaultUser1Assets");
        assertApproxEqAbs(vault.balanceOf(user1), state.vaultUser1Balance, tolerance, "vaultUser1Balance");
        assertApproxEqAbs(vault.assetsOf(user2),  state.vaultUser2Assets,  tolerance, "vaultUser2Assets");
        assertApproxEqAbs(vault.balanceOf(user2), state.vaultUser2Balance, tolerance, "vaultUser2Balance");
    }

    function _assertTestState(TestState memory state) internal view {
        _assertTestState(state, 0);
    }

}
