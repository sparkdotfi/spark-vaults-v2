// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "./b_flows_erc4626.sol";

contract FlowsOther is FlowsErc4626 {

    constructor(address _vault) FlowsErc4626(_vault) {}

    function setVsrBounds(
        uint256 minVsr,
        uint256 maxVsr
    ) public {
        numCalls["setVsrBounds"]++;
        minVsr = _bound(minVsr, RAY,    FOUR_PCT_VSR);  // between 0% and 4% apy
        maxVsr = _bound(maxVsr, minVsr, MAX_VSR);       // between minVsr and 100% apy
        vm.prank(admin);
        vault.setVsrBounds(minVsr, maxVsr);
    }

    function setVsr(uint256 vsr) public {
        numCalls["setVsr"]++;
        vsr = _bound(vsr, vault.minVsr(), vault.maxVsr());
        vm.prank(setter);
        vault.setVsr(vsr);
    }

    function warp(uint256 secs) public {
        numCalls["warp"]++;
        secs = _bound(secs, 0, 365 days);
        vm.warp(block.timestamp + secs);
    }

    function drip() public {
        numCalls["drip"]++;
        vault.drip();
    }

    function take(uint256 amount) public {
        numCalls["take"]++;
        amount = _bound(amount, 0, asset.balanceOf(address(vault)));
        vm.prank(taker);
        vault.take(amount);
    }

    function give(uint256 amount) public {
        numCalls["give"]++;
        amount = _bound(amount, 0, 10_000_000_000 * 10 ** asset.decimals());
        deal(address(asset), address(this), amount);
        asset.transfer(address(vault), amount);
    }

}
