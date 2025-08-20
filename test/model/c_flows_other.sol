// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./b_flows_erc4626.sol";

contract FlowsOther is FlowsErc4626 {

    constructor(address _vault) FlowsErc4626(_vault) {}

    function setSsr(bool authFail, uint256 failCallerSeed, uint256 ssr) external {
        numCalls["setSsr"]++;
        ssr = _bound(ssr, RAY, 1000000021979553151239153027); // between 0% and 100% apy
        if (authFail) {
            uint256 mod = 3 + users.length;
            failCallerSeed = _bound(failCallerSeed, 0, mod - 1);
            address caller;
            if (failCallerSeed == 0) {
                caller = address(this); // this contract
            } else if (failCallerSeed == 1) {
                caller = admin; // admin
            } else if (failCallerSeed == 2) {
                caller = taker; // taker
            } else {
                caller = users[failCallerSeed - 3]; // user
            }
            vm.expectRevert(abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                caller, SETTER_ROLE
            ));
            vm.prank(caller); vault.setSsr(ssr);
            return;
        }
        vm.prank(setter); vault.setSsr(ssr);
    }

    // function warp(uint256 secs) external {
    //     numCalls["warp"]++;
    //     secs = _bound(secs, 0, 365 days);
    //     vm.warp(block.timestamp + secs);
    // }

    // function drip() external {
    //     numCalls["drip"]++;
    //     vault.drip();
    // }

    function take(uint256 amount) external {
        numCalls["take"]++;
        amount = _bound(amount, 0, asset.balanceOf(address(vault)));
        vm.prank(taker);
        vault.take(amount);
    }
}
