// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

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

        // bytes4[] memory selectors = new bytes4[](1);
        // selectors[0] = FlowsOther.script.selector;
        // targetSelector(FuzzSelector({
        //     selectors: selectors,
        //     addr: address(handler)
        // }));

        // Foundry will call only this contract's functions
        targetContract(address(handler));
    }

    function invariants() public {
        inv_lastBalanceOf();
        inv_lastAssetsOf();
        // inv_maxDeposit();
        // inv_maxMint();
        inv_maxRedeem();
        inv_maxWithdraw();
        inv_totalAssets();
        inv_assetsOf();
        inv_assetsOutstanding();
        inv_nowChi_eq_drip();
        inv_call_summary();
    }

    function inv_lastBalanceOf() internal view {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user          = handler.users(i);
            uint256 lastBalanceOf = handler.lastBalanceOf(user);
            uint256 balanceOf     = vault.balanceOf(user);
            assertEq(lastBalanceOf, balanceOf);
        }
    }

    function inv_lastAssetsOf() internal view {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user          = handler.users(i);
            uint256 lastAssetsOf  = handler.lastAssetsOf(user);
            uint256 assetsOf      = vault.assetsOf(user);
            assertLe(lastAssetsOf, assetsOf);
        }
    }

    // TODO: Decide what to do with this
    // function inv_maxDeposit() internal {
    // }

    // TODO: Decide what to do with this
    // function inv_maxMint() internal {
    //     for (uint256 i = 0; i < handler.N(); i++) {
    //         address user    = handler.users(i);
    //         uint256 shares  = vault.balanceOf(user);
    //         uint256 maxMint = vault.maxMint(user);
    //         vm.startPrank(user);
    //         deal(address(asset), user, type(uint256).max);
    //         asset.approve(address(vault), type(uint256).max);
    //
    //         if (maxMint == type(uint256).max) {
    //             // See if it is really possible
    //             uint256 assets = vault.previewMint(maxMint);
    //             vault.mint(maxMint, user);
    //             return;
    //         }
    //
    //         vm.expectRevert();
    //         vault.mint(maxMint + 1, user);
    //         vault.mint(maxMint, user);
    //     }
    // }

    function inv_maxRedeem() internal {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user      = handler.users(i);
            uint256 shares    = vault.balanceOf(user);
            uint256 maxRedeem = vault.maxRedeem(user);

            // TODO: Once this is implemented
        }

    }

    function inv_maxWithdraw() internal {
        for (uint256 i = 0; i < handler.N(); i++) {
            address user        = handler.users(i);
            uint256 shares      = vault.balanceOf(user);
            uint256 maxWithdraw = vault.maxWithdraw(user);
            vm.startPrank(user);
            // vm.expectRevert("Vault/insufficient-balance");
            // vault.withdraw(maxWithdraw + 1, user, user);
            // vault.withdraw(maxWithdraw, user, user);
            vm.stopPrank();
        }
    }

    function inv_totalAssets() internal view {
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

    function inv_assetsOf() internal view {
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

    function inv_assetsOutstanding() internal view {
        uint256 assets = vault.totalAssets();

        uint256 sharesToAssets = assets * RAY / vault.nowChi();
        uint256 assetBalance   = asset.balanceOf(address(vault));

        if (sharesToAssets >= assetBalance) {
            assertEq(vault.assetsOutstanding(), sharesToAssets - assetBalance);
        } else {
            // TODO: Once this is implemented
            // assertEq(vault.assetsOutstanding(), 0);
        }
    }

    function inv_nowChi_eq_drip() internal {
        uint256 nowChi = vault.nowChi();
        uint256 drip = vault.drip();

        assertEq(nowChi, drip);
    }

    function inv_call_summary() internal view { // make external to enable
        console.log("------------------");
        console.log("\nCall Summary\n");

        console.log("deposit",      handler.numCalls("deposit"));
        console.log("mint",         handler.numCalls("mint"));
        console.log("withdraw",     handler.numCalls("withdraw"));
        console.log("withdrawAll",  handler.numCalls("withdrawAll"));
        console.log("redeem",       handler.numCalls("redeem"));
        console.log("redeemAll",    handler.numCalls("redeemAll"));
        console.log("setSsrBounds", handler.numCalls("setSsrBounds"));
        console.log("setSsr",       handler.numCalls("setSsr"));
        console.log("warp",         handler.numCalls("warp"));
        console.log("drip",         handler.numCalls("drip"));
        console.log("take",         handler.numCalls("take"));
    }

}
