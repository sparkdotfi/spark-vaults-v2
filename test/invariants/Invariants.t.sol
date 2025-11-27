// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { SparkVaultInvariantTestBase } from "./InvariantsBase.t.sol";

import { AdminHandler }    from "./handlers/AdminHandler.sol";
import { ExternalHandler } from "./handlers/ExternalHandler.sol";
import { UserHandler }     from "./handlers/UserHandler.sol";

contract SparkVaultInvariantTest is SparkVaultInvariantTestBase {

    function setUp() public override {
        super.setUp();

        // For the purposes of these tests, set unlimited deposit cap
        vm.prank(admin);
        vault.setDepositCap(type(uint256).max);

        adminHandler    = new AdminHandler(address(vault));
        externalHandler = new ExternalHandler(address(vault));
        userHandler     = new UserHandler(address(vault), 25);

        // Foundry will call only the functions of the target contracts
        targetContract(address(adminHandler));
        targetContract(address(externalHandler));
        targetContract(address(userHandler));
    }

    function invariant_userInvariants() public {
        // NOTE: Skipping invariants C and D because they don't apply when deposit cap is set to type(uint256).max
        for (uint256 i = 0; i < userHandler.numUsers(); i++) {
            address user = userHandler.users(i);
            this.userInvariant_A_balanceOfCannotChange(user);
            this.userInvariant_B_assetsOfCannotDecrease(user);
            this.userInvariant_E_userCannotRedeemMoreThanMax(user);
            this.userInvariant_F_userCannotWithdrawMoreThanMax(user);
            this.userInvariant_G_userCanDepositAndWithdrawAtomically(user);
            this.userInvariant_H_assetsOfLeTotalAssets(user);
            this.userInvariant_I_maxRedeemLeBalance(user);
            this.userInvariant_J_maxWithdrawLeAssets(user);
            this.userInvariant_K_conversionSymmetry(user);
        }
    }

    function invariant_vaultInvariants() public {
        this.vaultInvariant_A_sumUserSharesEqTotalSupply();
        this.vaultInvariant_B_sumUserAssetsLeTotalAssets();
        this.vaultInvariant_C_assetsOutstandingLeTotalAssets();
        this.vaultInvariant_D_nowChiEqualsDrip();
        this.vaultInvariant_E_totalAssetsConversion();
    }

    function afterInvariant() public {
        // Simulate bank run, draining all liquidity
        this.simulateBankRun();

        _checkInvariantsOverTime();

        // Return 10% of the total assets to the vault
        _give(vault.totalAssets() / 10);

        _checkInvariantsOverTime();

        // Simulate a second bank run, draining all liquidity
        this.simulateBankRun();

        _checkInvariantsOverTime();

        // Set VSR to 0% APY to freeze liabilities
        adminHandler.setVsrBounds(1e27, 1e27);
        adminHandler.setVsr(1e27);

        _checkInvariantsOverTime();

        // Return remaining amount of total assets to the vault
        _give(vault.totalAssets());

        assertEq(vault.assetsOutstanding(), 0);

        // Simulate a third bank run, performing a full exit
        this.simulateBankRun();

        _checkInvariantsOverTime();

        assertEq(vault.totalSupply(),       0);
        assertEq(vault.totalAssets(),       0);
        assertEq(vault.assetsOutstanding(), 0);
    }

    function _checkInvariantsOverTime() public {
        this.invariant_userInvariants();
        this.invariant_vaultInvariants();

        skip(30 minutes);

        this.invariant_userInvariants();
        this.invariant_vaultInvariants();
    }

    // NOTE: Need an unbounded version of this function to ensure totalAssets is always reached
    function _give(uint256 amount) public {
        address taker = adminHandler.taker();
        deal(address(asset), taker, amount);

        vm.prank(taker);
        asset.transfer(address(vault), amount);
    }

}