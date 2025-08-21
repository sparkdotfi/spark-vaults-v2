// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./b_flows_erc4626.sol";

contract FlowsOther is FlowsErc4626 {

    constructor(address _vault) FlowsErc4626(_vault) {}

    function script() public {
    }

    function setSsrBounds(
        uint256 minSsr,
        uint256 maxSsr
    ) public {
        numCalls["setSsrBounds"]++;
        minSsr = _bound(minSsr, RAY, FOUR_PCT_SSR); // between 0% and 4% apy
        maxSsr = _bound(maxSsr, minSsr, MAX_SSR); // between minSsr and 100% apy
        vm.prank(admin);
        vault.setSsrBounds(minSsr, maxSsr);
    }

    function setSsr(bool authFail, uint256 failCallerSeed, uint256 ssr) public {
        numCalls["setSsr"]++;
        ssr = _bound(ssr, vault.minSsr(), vault.maxSsr());
        vm.prank(setter);
        vault.setSsr(ssr);
    }

    // function warp(uint256 secs) public {
    //     numCalls["warp"]++;
    //     secs = _bound(secs, 0, 365 days);
    //     vm.warp(block.timestamp + secs);
    // }

    // function drip() public {
    //     numCalls["drip"]++;
    //     vault.drip();
    // }

    function take(uint256 amount) public {
        numCalls["take"]++;
        amount = _bound(amount, 0, asset.balanceOf(address(vault)));
        vm.prank(taker);
        vault.take(amount);
    }

}
