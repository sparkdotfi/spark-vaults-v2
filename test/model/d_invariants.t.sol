// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "./c_flows_other.sol";

import { SparkVaultTestBase } from "../TestBase.t.sol";

contract SparkVaultInvariantTest is SparkVaultTestBase {

    // NOTE: This cannot be part of SparkVaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant internal RAY = 1e27;

    FlowsOther handler;

    function setUp() public override {
        super.setUp();

        handler = new FlowsOther(address(vault));

        // Foundry will call only this contract's functions
        targetContract(address(handler));
    }

    function invariant_lastBalanceOf() public view {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user          = handler.users(i);
            uint256 lastBalanceOf = handler.lastBalanceOf(user);
            uint256 balanceOf     = vault.balanceOf(user);
            assertEq(lastBalanceOf, balanceOf);
        }
    }

    function invariant_lastAssetsOf() public view {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user          = handler.users(i);
            uint256 lastAssetsOf  = handler.lastAssetsOf(user);
            uint256 assetsOf      = vault.assetsOf(user);
            assertGe(assetsOf, lastAssetsOf);
        }
    }

    function invariant_maxRedeem() public {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user      = handler.users(i);
            uint256 maxRedeem = vault.maxRedeem(user);

            vm.startPrank(user);
            vm.expectRevert();
            vault.redeem(maxRedeem + 2, user, user);
            vault.redeem(maxRedeem, user, user);
            vm.stopPrank();
        }

    }

    function invariant_maxWithdraw() public {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user        = handler.users(i);
            uint256 maxWithdraw = vault.maxWithdraw(user);
            vm.startPrank(user);
            // There will EITHER be not enough liquidity (SparkVault/insufficient-liquidity) (if
            // take is run) OR the user will not have enough assets
            // (SparkVault/insufficient-balance)
            vm.expectRevert();
            vault.withdraw(maxWithdraw + 2, user, user);
            vault.withdraw(maxWithdraw, user, user);
            vm.stopPrank();
        }
    }

    function invariant_totalAssets() public view {
        uint256 totalAssets = vault.totalAssets();
        uint256 totalShares = vault.totalSupply();

        if (totalShares == 0) {
            assertEq(totalAssets, 0);
        } else {
            uint256 totalAssetsExpected = totalShares * vault.nowChi() / RAY;
            assertGt(totalAssetsExpected, 0);
            assertEq(totalAssets, totalAssetsExpected);
        }
    }

    function invariant_assetsOf() public view {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user = handler.users(i);
            uint256 shares = vault.balanceOf(user);
            uint256 assets = vault.assetsOf(user);

            if (shares == 0) {
                assertEq(assets, 0);
            } else {
                uint256 assetsExpected = shares * vault.nowChi() / RAY;
                assertGt(assetsExpected, 0);
                assertEq(assets, assetsExpected);
                assertLe(assetsExpected, vault.totalAssets());
            }
        }
    }

    function invariant_assetsOutstanding() public view {
        uint256 assets = vault.totalAssets();
        uint256 assetBalance   = asset.balanceOf(address(vault));

        if (assets >= assetBalance) {
            assertEq(vault.assetsOutstanding(), assets - assetBalance);
        } else {
            assertEq(vault.assetsOutstanding(), 0);
        }
    }

    function invariant_nowChi_eq_drip() public {
        uint256 nowChi = vault.nowChi();
        uint256 drip = vault.drip();

        assertEq(nowChi, drip);
    }

    function invariant_call_summary() public view {
        console.log("------------------");
        console.log("\nCall Summary\n");

        console.log("deposit",      handler.numCalls("deposit"));
        console.log("mint",         handler.numCalls("mint"));
        console.log("withdraw",     handler.numCalls("withdraw"));
        console.log("redeem",       handler.numCalls("redeem"));
        console.log("setVsrBounds", handler.numCalls("setVsrBounds"));
        console.log("setVsr",       handler.numCalls("setVsr"));
        console.log("warp",         handler.numCalls("warp"));
        console.log("drip",         handler.numCalls("drip"));
        console.log("take",         handler.numCalls("take"));
        console.log("give",         handler.numCalls("give"));
    }

}
