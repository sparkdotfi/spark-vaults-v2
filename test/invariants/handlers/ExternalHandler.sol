// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { HandlerBase } from "./HandlerBase.sol";

contract ExternalHandler is HandlerBase {

    constructor(address vault_) HandlerBase(vault_) {}

    function warp(uint256 secs) public totalAssetsCheck accountingCheck {
        secs = _bound(secs, 0, 10 days);
        vm.warp(block.timestamp + secs);
    }

    function drip() public totalAssetsCheck accountingCheck {
        vault.drip();
    }

    function give(uint256 amount) public totalAssetsCheck accountingCheck {
        amount = _bound(amount, 0, 10_000_000_000 * 10 ** asset.decimals());
        deal(address(asset), address(this), amount);
        asset.transfer(address(vault), amount);
    }

}