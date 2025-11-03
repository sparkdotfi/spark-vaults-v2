// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { AdminHandler }    from "./handlers/AdminHandler.sol";
import { ExternalHandler } from "./handlers/ExternalHandler.sol";
import { UserHandler }     from "./handlers/UserHandler.sol";

import { SparkVaultTestBase } from "../TestBase.t.sol";

contract SparkVaultInvariantTestBase is SparkVaultTestBase {

    // NOTE: This cannot be part of SparkVaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant internal RAY = 1e27;

    AdminHandler    adminHandler;
    ExternalHandler externalHandler;
    UserHandler     userHandler;

    /**********************************************************************************************/
    /*** User invariant helper functions                                                        ***/
    /**********************************************************************************************/

    function _userInvariant_balanceOfCannotChange(address user) internal view {
        assertEq(
            userHandler.lastBalanceOf(user),
            vault.balanceOf(user),
            string(abi.encodePacked("balanceOf cannot change for user ", user))
        );
    }

    function _userInvariant_assetsOfCannotDecrease(address user) internal view {
        assertGe(
            vault.assetsOf(user),
            userHandler.lastAssetsOf(user),
            string(abi.encodePacked("assetsOf cannot decrease for user ", user))
        );
    }

    function _userInvariant_userCannotDepositMoreThanMax(address user) internal {
        uint256 id = vm.snapshot();

        vm.startPrank(user);
        vm.expectRevert("SparkVault/deposit-cap-exceeded");
        vault.deposit(vault.maxDeposit(user) + 2, user);

        vault.deposit(vault.maxDeposit(user), user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function _userInvariant_userCannotMintMoreThanMax(address user) internal {
        uint256 id = vm.snapshot();

        vm.startPrank(user);
        vm.expectRevert("SparkVault/deposit-cap-exceeded");
        vault.mint(vault.maxMint(user) + 2, user);
        vault.mint(vault.maxMint(user), user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function _userInvariant_userCannotRedeemMoreThanMax(address user) internal {
        uint256 id = vm.snapshot();

        vm.startPrank(user);
        vm.expectRevert("SparkVault/insufficient-balance");
        vault.redeem(vault.maxRedeem(user) + 2, user, user);
        vault.redeem(vault.maxRedeem(user),     user, user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function _userInvariant_userCannotWithdrawMoreThanMax(address user) internal {
        uint256 id = vm.snapshot();

        vm.startPrank(user);
        vm.expectRevert("SparkVault/insufficient-balance");
        vault.withdraw(vault.maxWithdraw(user) + 2, user, user);
        vault.withdraw(vault.maxWithdraw(user),     user, user);
        vm.stopPrank();

        vm.revertTo(id);
    }

    function _userInvariant_userCanDepositAndWithdrawAtomically(address user) internal {
        uint256 id = vm.snapshot();

        vm.startPrank(user);

        deal(address(asset), address(user), 1e18);
        asset.approve(address(vault), 1e18);
        uint256 shares = vault.deposit(1e18, user);
        uint256 assets = vault.redeem(shares, user, user);

        assertApproxEqAbs(
            assets,
            1e18,
            2,
            string(abi.encodePacked("User ", user, " cannot deposit and redeem atomically"))
        );

        vm.stopPrank();

        vm.revertTo(id);
    }

    function _userInvariant_assetsOfLeTotalAssets(address user) internal view {
        assertLe(
            vault.assetsOf(user),
            vault.totalAssets(),
            string(abi.encodePacked("assetsOf cannot be greater than totalAssets for user ", user))
        );
    }

    function _userInvariant_maxRedeemLeBalance(address user) internal view {
        assertLe(
            vault.maxRedeem(user),
            vault.balanceOf(user),
            string(abi.encodePacked("maxRedeem cannot be greater than balanceOf for user ", user))
        );
    }

    function _userInvariant_maxWithdrawLeAssets(address user) internal view {
        assertLe(
            vault.maxWithdraw(user),
            vault.assetsOf(user),
            string(abi.encodePacked("maxWithdraw cannot be greater than assetsOf for user ", user))
        );
    }

    function _userInvariant_conversionSymmetry(address user) internal view {
        uint256 assets = vault.assetsOf(user);
        uint256 shares = vault.balanceOf(user);

        assertEq(
            vault.convertToAssets(vault.convertToShares(assets)),
            assets,
            string(abi.encodePacked("convertToAssets and convertToShares are not symmetric for user ", user))
        );
        assertEq(
            vault.convertToShares(vault.convertToAssets(shares)),
            shares,
            string(abi.encodePacked("convertToAssets and convertToShares are not symmetric for user ", user))
        );
    }

    /**********************************************************************************************/
    /*** Vault invariant helper functions                                                       ***/
    /**********************************************************************************************/

    function _vaultInvariant_sumUserSharesEqTotalSupply() internal view {
        uint256 sum;
        for (uint256 i = 0; i < userHandler.N(); i++) {
            sum += vault.balanceOf(userHandler.users(i));
        }
        assertEq(sum, vault.totalSupply());
    }

    function _vaultInvariant_sumUserAssetsLeTotalAssets() internal view {
        uint256 sum;
        for (uint256 i = 0; i < userHandler.N(); i++) {
            sum += vault.assetsOf(userHandler.users(i));
        }
        assertLe(sum, vault.totalAssets());
    }

    function _vaultInvariant_assetsOutstandingLeTotalAssets() internal view {
        assertLe(vault.assetsOutstanding(), vault.totalAssets());
    }

    function _vaultInvariant_nowChiEqualsdrip() internal {
        assertEq(vault.nowChi(), vault.drip());
    }

    function _vaultInvariant_totalAssetsConversion() internal view {
        assertEq(vault.totalAssets(), vault.totalSupply() * vault.nowChi() / RAY);
    }

}
