// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { AdminHandler }    from "./handlers/AdminHandler.sol";
import { ExternalHandler } from "./handlers/ExternalHandler.sol";
import { UserHandler }     from "./handlers/UserHandler.sol";

import { SparkVaultTestBase } from "../TestBase.t.sol";

contract SparkVaultInvariantTestBase is SparkVaultTestBase {

    // NOTE: This cannot be part of SparkVaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant public RAY = 1e27;

    AdminHandler    adminHandler;
    ExternalHandler externalHandler;
    UserHandler     userHandler;

    /**********************************************************************************************/
    /*** User invariant helper functions                                                        ***/
    /**********************************************************************************************/

    function userInvariant_A_balanceOfCannotChange(address user) public view {
        assertEq(
            userHandler.lastBalanceOf(user),
            vault.balanceOf(user),
            string(abi.encodePacked("balanceOf cannot change for user ", vm.toString(user)))
        );
    }

    function userInvariant_B_assetsOfCannotDecrease(address user) public view {
        assertGe(
            vault.assetsOf(user),
            userHandler.lastAssetsOf(user),
            string(abi.encodePacked("assetsOf cannot decrease for user ", vm.toString(user)))
        );
    }

    function userInvariant_C_userCannotDepositMoreThanMax(address user) public {
        uint256 id = vm.snapshot();

        uint256 maxDeposit = vault.maxDeposit(user);

        deal(address(asset), user, maxDeposit + 2);

        vm.startPrank(user);
        vm.expectRevert("SparkVault/deposit-cap-exceeded");
        vault.deposit(maxDeposit + 2, user);

        vault.deposit(maxDeposit, user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function userInvariant_D_userCannotMintMoreThanMax(address user) public {
        uint256 id = vm.snapshot();

        uint256 maxMint = vault.maxMint(user);

        deal(address(asset), user, vault.convertToAssets(maxMint + 2));

        vm.startPrank(user);
        vm.expectRevert("SparkVault/deposit-cap-exceeded");
        vault.mint(maxMint + 2, user);
        vault.mint(maxMint, user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function userInvariant_E_userCannotRedeemMoreThanMax(address user) public {
        uint256 id = vm.snapshot();

        uint256 maxRedeem = vault.maxRedeem(user);

        vm.startPrank(user);
        vm.expectRevert();  // SparkVault/insufficient-balance || SparkVault/insufficient-liquidity
        vault.redeem(maxRedeem + 2, user, user);
        vault.redeem(maxRedeem,     user, user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function userInvariant_F_userCannotWithdrawMoreThanMax(address user) public {
        uint256 id = vm.snapshot();

        uint256 maxWithdraw = vault.maxWithdraw(user);

        vm.startPrank(user);
        vm.expectRevert();  // SparkVault/insufficient-balance || SparkVault/insufficient-liquidity
        vault.withdraw(maxWithdraw + 2, user, user);
        vault.withdraw(maxWithdraw,     user, user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function userInvariant_G_userCanDepositAndWithdrawAtomically(address user) public {
        uint256 id = vm.snapshot();

        vm.startPrank(user);

        deal(address(asset), address(user), 1e18);
        asset.approve(address(vault), 1e18);
        uint256 shares = vault.deposit(1e18, user);
        uint256 assets = vault.redeem(shares, user, user);

        assertApproxEqAbs(
            assets,
            1e18,
            3,
            string(abi.encodePacked("User ", user, " cannot deposit and redeem atomically"))
        );

        vm.stopPrank();

        vm.revertTo(id);
    }

    function userInvariant_H_assetsOfLeTotalAssets(address user) public view {
        assertLe(
            vault.assetsOf(user),
            vault.totalAssets(),
            string(abi.encodePacked("assetsOf cannot be greater than totalAssets for user ", vm.toString(user)))
        );
    }

    function userInvariant_I_maxRedeemLeBalance(address user) public view {
        assertLe(
            vault.maxRedeem(user),
            vault.balanceOf(user),
            string(abi.encodePacked("maxRedeem cannot be greater than balanceOf for user ", vm.toString(user)))
        );
    }

    function userInvariant_J_maxWithdrawLeAssets(address user) public view {
        assertLe(
            vault.maxWithdraw(user),
            vault.assetsOf(user),
            string(abi.encodePacked("maxWithdraw cannot be greater than assetsOf for user ", vm.toString(user)))
        );
    }

    function userInvariant_K_conversionSymmetry(address user) public view {
        uint256 assets = vault.assetsOf(user);
        uint256 shares = vault.balanceOf(user);

        assertApproxEqAbs(
            vault.convertToAssets(vault.convertToShares(assets)),
            assets,
            2,
            string(abi.encodePacked("convertToAssets and convertToShares are not symmetric for user ", vm.toString(user)))
        );
        assertApproxEqAbs(
            vault.convertToShares(vault.convertToAssets(shares)),
            shares,
            2,
            string(abi.encodePacked("convertToAssets and convertToShares are not symmetric for user ", vm.toString(user)))
        );
    }

    /**********************************************************************************************/
    /*** Vault invariant helper functions                                                       ***/
    /**********************************************************************************************/

    function vaultInvariant_A_sumUserSharesEqTotalSupply() public view {
        uint256 sum;
        for (uint256 i = 0; i < userHandler.numUsers(); i++) {
            sum += vault.balanceOf(userHandler.users(i));
        }
        assertEq(sum, vault.totalSupply());
    }

    function vaultInvariant_B_sumUserAssetsLeTotalAssets() public view {
        uint256 sum;
        for (uint256 i = 0; i < userHandler.numUsers(); i++) {
            sum += vault.assetsOf(userHandler.users(i));
        }
        assertLe(sum, vault.totalAssets());
    }

    function vaultInvariant_C_assetsOutstandingLeTotalAssets() public view {
        assertLe(vault.assetsOutstanding(), vault.totalAssets());
    }

    function vaultInvariant_D_nowChiEqualsDrip() public {
        assertEq(vault.nowChi(), vault.drip());
    }

    function vaultInvariant_E_totalAssetsConversion() public view {
        assertEq(vault.totalAssets(), vault.totalSupply() * vault.nowChi() / RAY);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function simulateBankRun() public {
        for (uint256 i = 0; i < userHandler.numUsers(); i++) {
            skip(2 minutes);

            address user = userHandler.users(i);

            uint256 userBalance = vault.balanceOf(user);
            uint256 userAssets  = vault.assetsOf(user);

            vm.startPrank(user);

            // If possible, redeem all shares to withdraw full position
            try vault.redeem(userBalance, user, user) {
                assertEq(vault.balanceOf(user), 0);
                assertEq(vault.assetsOf(user),  0);

                // Update handler state to assert invariants
                _setLastBalanceOf(user, 0);
                _setLastAssetsOf(user, 0);
                _setTotalBalance(userHandler.totalBalance() - userBalance);
            }

            // If not possible to redeem all shares, withdraw max possible amount
            // to drain remaining liquidity
            catch (bytes memory) {
                uint256 maxWithdraw = vault.maxWithdraw(user);

                uint256 shares = vault.withdraw(maxWithdraw, user, user);

                // Vault liquidity is drained
                assertEq(asset.balanceOf(address(vault)), 0);
                assertEq(vault.totalAssets(),             vault.assetsOutstanding());

                // Update handler state to assert invariants
                _setLastBalanceOf(user, userBalance - shares);
                _setLastAssetsOf(user, vault.assetsOf(user));  // Query directly to account for rounding
                _setTotalBalance(userHandler.totalBalance() - shares);

                vm.stopPrank();

                return;
            }

            vm.stopPrank();
        }
    }

    // NOTE: Have to set directly to not expose setters as part of the public interface
    function _setLastBalanceOf(address user, uint256 lastBalanceOf) public {
        vm.store(address(userHandler), keccak256(abi.encode(user, 36)), bytes32(lastBalanceOf));
        assertEq(
            userHandler.lastBalanceOf(user),
            lastBalanceOf,
            string(abi.encodePacked("lastBalanceOf cannot be set for user ", vm.toString(user)))
        );
    }

    function _setLastAssetsOf(address user, uint256 lastAssetsOf) public {
        vm.store(address(userHandler), keccak256(abi.encode(user, 37)), bytes32(lastAssetsOf));
        assertEq(
            userHandler.lastAssetsOf(user),
            lastAssetsOf,
            string(abi.encodePacked("lastAssetsOf cannot be set for user ", vm.toString(user)))
        );
    }

    function _setTotalBalance(uint256 totalBalance) public {
        vm.store(address(userHandler), bytes32(uint256(38)), bytes32(totalBalance));
        assertEq(
            userHandler.totalBalance(),
            totalBalance,
            string(abi.encodePacked("totalBalance cannot be set"))
        );
    }

}
