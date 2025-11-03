// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { HandlerBase } from "./HandlerBase.sol";

contract AdminHandler is HandlerBase {

    address public admin;
    address public setter;
    address public taker;

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 TAKER_ROLE         = keccak256("TAKER_ROLE");

    uint256 constant ONE_PCT_VSR   = 1.000000000315522921573372069e27;
    uint256 constant FOUR_PCT_VSR  = 1.000000001243680656318820312e27;
    uint256 constant FORTY_PCT_VSR = 1.000000010669464688489416886e27;  // 40% APY
    uint256 constant MAX_VSR       = 1.000000021979553151239153027e27;  // 100% APY

    constructor(address vault_) HandlerBase(vault_) {
        admin  = vault.getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        setter = vault.getRoleMember(SETTER_ROLE,        0);
        taker  = vault.getRoleMember(TAKER_ROLE,         0);
    }

    function setVsrBounds(
        uint256 minVsr,
        uint256 maxVsr
    ) public totalAssetsCheck accountingCheck {
        minVsr = _bound(minVsr, RAY,    FOUR_PCT_VSR);   // between 0% and 4% apy
        maxVsr = _bound(maxVsr, minVsr, FORTY_PCT_VSR);  // between minVsr and 40% apy
        vm.prank(admin);
        vault.setVsrBounds(minVsr, maxVsr);
    }

    function setVsr(uint256 vsr) public totalAssetsCheck accountingCheck {
        vsr = _bound(vsr, vault.minVsr(), vault.maxVsr());
        vm.prank(setter);
        vault.setVsr(vsr);
    }

    function take(uint256 amount) public totalAssetsCheck accountingCheck {
        amount = _bound(amount, 0, asset.balanceOf(address(vault)));
        vm.prank(taker);
        vault.take(amount);
    }

}