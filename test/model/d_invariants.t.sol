// SPDX-License-Identifier: AGPL-3.0-or-later

import "./c_flows_other.sol";

contract VaultInvariantsTest is Test {
    IERC20   asset;
    IVault   proxy;
    IVault   impl;
    FlowsOther handler;

    function setUp() public {
        handler = new FlowsOther();

         // uncomment and fill to only call specific functions
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = FlowsOther.setSsr.selector;
        // selectors[1] = FlowsOther.warp.selector;3       // selectors[2] = FlowsOther.drip.selector;
        // selectors[3] = FlowsOther.deposit.selector;
        // selectors[4] = FlowsOther.mint.selector;
        // selectors[5] = FlowsOther.withdraw.selector;
        // selectors[6] = FlowsOther.withdrawAll.selector;
        // selectors[7] = FlowsOther.redeem.selector;
        // selectors[8] = FlowsOther.redeemAll.selector;

        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));

        targetContract(address(handler)); // invariant tests should fuzz only handler functions
    }

    function invariant_usds_balance_vs_redeemable() external view {
        // for only setSsr, warp, drip
        // assertEq(usds.balanceOf(address(proxy)), proxy.totalSupply() * proxy.chi() / RAY);

        // for everything
        // assertGe(usds.balanceOf(address(proxy)), proxy.totalSupply() * proxy.chi() / RAY);
    }

    function invariant_call_summary() private view { // make external to enable
        console.log("------------------");

        console.log("\nCall Summary\n");
        console.log("setSsr", handler.numCalls("setSsr"));
        console.log("warp", handler.numCalls("warp"));
        console.log("drip", handler.numCalls("drip"));
        console.log("deposit", handler.numCalls("deposit"));
        console.log("mint", handler.numCalls("mint"));
        console.log("withdraw", handler.numCalls("withdraw"));
        console.log("withdrawAll", handler.numCalls("withdrawAll"));
        console.log("redeem", handler.numCalls("redeem"));
        console.log("redeemAll", handler.numCalls("redeemAll"));
    }
}
