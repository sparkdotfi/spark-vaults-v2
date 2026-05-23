// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.35;

import { Test } from "../../lib/forge-std/src/Test.sol";

import { ERC20Mock }    from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import { ERC1967Proxy } from "../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SparkBoostedVault }  from "../../src/SparkBoostedVault.sol";
import { ISparkBoostedVault } from "../../src/ISparkBoostedVault.sol";

contract SparkBoostedVaultTestBase is Test {

    uint256 internal constant RAY          = 1e27;
    uint256 internal constant ONE_PCT_VSR  = 1.000000000315522921573372069e27;
    uint256 internal constant FOUR_PCT_VSR = 1.000000001243680656318820312e27;
    uint256 internal constant TEN_PCT_VSR  = 1.000000003022265980097387650e27;
    uint256 internal constant MAX_VSR      = 1.000000021979553151239153027e27;

    uint64 internal constant TERM  = 365 days;
    uint64 internal constant CLIFF = 90 days;

    address internal admin  = makeAddr("admin");
    address internal setter = makeAddr("setter");
    address internal taker  = makeAddr("taker");

    bytes32 internal DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 internal TAKER_ROLE         = keccak256("TAKER_ROLE");

    ERC20Mock         internal asset;
    SparkBoostedVault internal vault;

    function setUp() public virtual {
        asset = new ERC20Mock();

        vault = SparkBoostedVault(
            address(new ERC1967Proxy(
                address(new SparkBoostedVault()),
                abi.encodeCall(
                    SparkBoostedVault.initialize,
                    (address(asset), admin, TERM, CLIFF)
                )
            ))
        );

        vm.startPrank(admin);

        vault.grantRole(SETTER_ROLE, setter);

        vault.grantRole(TAKER_ROLE,  taker);

        vault.setMaxLiabilityCap(1_000_000e6);

        vm.stopPrank();
    }

    // Deposit assets into the vault.
    function _deposit(address user, uint256 amount) internal returns (uint256 positionId) {
        deal(address(asset), user, amount);

        vm.startPrank(user);

        asset.approve(address(vault), amount);

        positionId = vault.deposit(amount);

        vm.stopPrank();
    }

    // Enable yield: open VSR bounds to [RAY, vsrValue] and set VSR.
    function _setVsr(uint256 maxVsr) internal {
        vm.prank(admin);
        vault.setVsrBounds(RAY, maxVsr);

        vm.prank(setter);
        vault.setVsr(maxVsr);
    }

    // Deal the vault's asset balance up to its current maxLiability() so withdrawals succeed.
    function _fundVaultToTotalAssets() internal {
        deal(address(asset), address(vault), vault.maxLiability());
    }

}

contract SparkBoostedVaultIntegrationTests is SparkBoostedVaultTestBase {

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function _assetsOf(uint256 positionId) internal view returns (uint256) {
        return vault.getPosition(positionId).principal + vault.yieldOf(positionId);
    }

    /**********************************************************************************************/
    /*** Single user e2e tests                                                                  ***/
    /**********************************************************************************************/

    function test_e2e_singleUser_withdrawFullTerm() external {
        uint256 amount = 100_000e6;

        _setVsr(FOUR_PCT_VSR);

        // Step 1: User 1 deposits
        uint256 pos1 = _deposit(user1, amount);

        // Step 2: Wait full term
        skip(TERM);

        // Step 3: User withdraws receiving principal + full yield
        assertEq(vault.vestingMultiplierOf(pos1), RAY);
        assertEq(vault.unvestedYieldOf(pos1),   0);

        uint256 rawAssets = _assetsOf(pos1);

        assertGt(rawAssets,                   amount);  // shows yield accrued
        assertEq(vault.withdrawableOf(pos1), rawAssets);
        assertEq(vault.vestedYieldOf(pos1),  rawAssets - amount);

        _fundVaultToTotalAssets();

        vm.prank(user1);
        vault.withdraw(pos1);

        assertEq(asset.balanceOf(user1),          rawAssets);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(vault.totalShares(),             0);
        assertEq(vault.totalPrincipal(),          0);
        assertEq(vault.maxLiability(),            0);

        ISparkBoostedVault.Position memory position = vault.getPosition(pos1);
        assertEq(position.principal,   0);
        assertEq(position.shares,      0);
        assertEq(position.depositTime, 0);
    }

    function test_e2e_singleUser_exitsBeforeCliff() external {
        uint256 amount = 100_000e6;

        _setVsr(FOUR_PCT_VSR);

        // Step 1: User 1 deposits
        uint256 pos1 = _deposit(user1, amount);

        // Step 2: Wait just before cliff
        skip(CLIFF - 1);

        // Step 3: User withdraws receiving only principal
        assertEq(vault.vestingMultiplierOf(pos1), 0);
        assertEq(vault.vestedYieldOf(pos1),     0);
        assertEq(vault.withdrawableOf(pos1),    amount);

        uint256 unvestedYield = vault.unvestedYieldOf(pos1);

        assertGt(unvestedYield, 0);

        _fundVaultToTotalAssets();

        assertEq(asset.balanceOf(address(vault)), amount + unvestedYield);

        vm.prank(user1);
        vault.withdraw(pos1);

        assertEq(asset.balanceOf(user1),          amount);
        assertEq(asset.balanceOf(address(vault)), unvestedYield);
        assertEq(vault.totalShares(),             0);
        assertEq(vault.totalPrincipal(),          0);
        assertEq(vault.maxLiability(),            0);

        // Step 4: Taker claims the forfeited yield
        assertEq(asset.balanceOf(taker),          0);
        assertEq(asset.balanceOf(address(vault)), unvestedYield);

        vm.prank(taker);
        vault.take(unvestedYield);

        assertEq(asset.balanceOf(taker),          unvestedYield);
        assertEq(asset.balanceOf(address(vault)), 0);
    }

    function testFuzz_e2e_singleUser_exitsMidVesting(uint256 elapsed) external {
        elapsed = bound(elapsed, CLIFF + 1, TERM - 1);

        uint256 amount = 100_000e6;

        _setVsr(FOUR_PCT_VSR);

        // Step 1: User 1 deposits
        uint256 pos1 = _deposit(user1, amount);

        // Step 2: Wait for elapsed time
        skip(elapsed);

        // Step 3: User withdraws receiving partial yield
        uint256 multiplier = vault.vestingMultiplierOf(pos1);
        uint256 rawYield   = _assetsOf(pos1) - amount;

        assertGt(multiplier, 0);
        assertLt(multiplier, RAY);

        uint256 expectedVested   = rawYield * multiplier / RAY;
        uint256 expectedUnvested = rawYield - expectedVested;

        assertEq(vault.vestedYieldOf(pos1),   expectedVested);
        assertEq(vault.unvestedYieldOf(pos1), expectedUnvested);
        assertEq(vault.withdrawableOf(pos1),  amount + expectedVested);

        _fundVaultToTotalAssets();

        assertEq(asset.balanceOf(user1),          0);
        assertEq(asset.balanceOf(address(vault)), amount + rawYield);
        assertEq(vault.maxLiability(),            amount + rawYield);

        vm.prank(user1);
        vault.withdraw(pos1);

        assertEq(asset.balanceOf(user1),          amount + expectedVested);
        assertEq(asset.balanceOf(address(vault)), expectedUnvested);
        assertEq(vault.maxLiability(),            0);
    }

    function test_e2e_singleUser_reDepositsAfterFullExit() external {
        uint256 amount = 100_000e6;

        _setVsr(FOUR_PCT_VSR);

        // Step 1: User 1 deposits
        uint256 pos1 = _deposit(user1, amount);

        // Step 2: Skip to term
        skip(TERM);

        // Step 3: User withdraws receiving principal + full yield
        _fundVaultToTotalAssets();

        uint256 firstWithdrawal = vault.withdrawableOf(pos1);

        assertEq(asset.balanceOf(user1),   0);
        assertEq(vault.getPosition(pos1).principal, amount);

        vm.prank(user1);
        vault.withdraw(pos1);

        assertEq(asset.balanceOf(user1),   firstWithdrawal);
        assertEq(vault.getPosition(pos1).principal, 0);

        // Step 4: User 1 re-deposits
        deal(address(asset), user1, firstWithdrawal);

        vm.startPrank(user1);
        asset.approve(address(vault), firstWithdrawal);
        uint256 pos2 = vault.deposit(firstWithdrawal);
        vm.stopPrank();

        assertEq(vault.getPosition(pos2).principal,   firstWithdrawal);
        assertEq(vault.getPosition(pos2).depositTime, uint64(block.timestamp));

        skip(TERM);

        _fundVaultToTotalAssets();

        uint256 secondWithdrawal = vault.withdrawableOf(pos2);

        assertGt(secondWithdrawal, firstWithdrawal);

        assertEq(asset.balanceOf(user1), 0);
        assertEq(vault.maxLiability(),    secondWithdrawal);

        vm.prank(user1);
        vault.withdraw(pos2);

        assertEq(asset.balanceOf(user1), secondWithdrawal);
        assertEq(vault.maxLiability(),    0);
    }

    /**********************************************************************************************/
    /*** Multi-user tests                                                                       ***/
    /**********************************************************************************************/

    // Two users deposit simultaneously - user1 exits before cliff (forfeits yield),
    // user2 holds to full term and receives all yield.
    function test_e2e_twoUsers_differentExitTimings() external {
        uint256 amount1 = 100_000e6;
        uint256 amount2 = 200_000e6;

        uint256 pos1 = _deposit(user1, amount1);
        uint256 pos2 = _deposit(user2, amount2);

        _setVsr(FOUR_PCT_VSR);

        assertEq(vault.totalShares(),    amount1 + amount2);
        assertEq(vault.totalPrincipal(), amount1 + amount2);

        // User1 exits before cliff: forfeits all yield.
        skip(CLIFF - 1);

        assertGt(vault.unvestedYieldOf(pos1),   0);
        assertEq(vault.vestingMultiplierOf(pos1), 0);
        assertEq(vault.withdrawableOf(pos1),    amount1);

        assertEq(asset.balanceOf(user1), 0);
        assertEq(vault.totalPrincipal(), amount1 + amount2);

        vm.prank(user1);
        vault.withdraw(pos1);

        assertEq(asset.balanceOf(user1), amount1);
        assertEq(vault.totalPrincipal(), amount2);

        // User2 holds until their full term (TERM elapsed since original deposit)
        skip(TERM - (CLIFF - 1));

        assertEq(vault.vestingMultiplierOf(pos2), RAY);

        _fundVaultToTotalAssets();

        uint256 user2Assets = _assetsOf(pos2);

        assertGt(user2Assets, amount2);

        assertEq(asset.balanceOf(user2), 0);
        assertEq(vault.totalPrincipal(), amount2);
        assertEq(vault.maxLiability(),    user2Assets);

        vm.prank(user2);
        vault.withdraw(pos2);

        assertEq(asset.balanceOf(user2), user2Assets);
        assertEq(vault.totalPrincipal(), 0);
        assertEq(vault.maxLiability(),    0);
    }

}
