// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2024 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.21;

import { StdUtils, StdCheats, Vm, Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControlEnumerable }
    from "openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

import { IVault } from "src/IVault.sol";

import { VaultDeploy } from "deploy/VaultDeploy.sol";


contract VaultHandler is StdUtils, StdCheats {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant SETTER_ROLE = keccak256("SETTER_ROLE");
    bytes32 constant TAKER_ROLE = keccak256("TAKER_ROLE");

    IERC20   asset;
    IVault   proxy;
    IVault   impl;

    address immutable admin;
    address immutable ssrSetter;
    address immutable taker;

    uint256 constant N = 5;

    address[N] users;

    mapping(bytes32 => uint256) public numCalls;

    uint256 constant RAY = 10 ** 27;

    constructor() {
        (address _asset, address _proxy, address _impl) = VaultDeploy.deployUsdsToEmptyChain();
        asset = IERC20(_asset); proxy = IVault(_proxy); impl = IVault(_impl);

        // This contract is at first DEFAULT_ADMIN_ROLE.
        IAccessControlEnumerable proxyACE = IAccessControlEnumerable(_proxy);
        require(proxyACE.getRoleMember(DEFAULT_ADMIN_ROLE, 0) == address(this));
        require(proxyACE.getRoleMemberCount(DEFAULT_ADMIN_ROLE) == 1);


        admin = vm.addr(1);
        ssrSetter = vm.addr(2);
        taker = vm.addr(3);

        proxyACE.grantRole(DEFAULT_ADMIN_ROLE, admin);
        proxyACE.grantRole(SETTER_ROLE, ssrSetter);
        proxyACE.grantRole(TAKER_ROLE, taker);

        for (uint256 i = 4; i < 4 + N; i++) {
            users[i - 4] = vm.addr(i);
        }
    }

    function setSsr(bool fail, uint256 failCallerIndex, uint256 ssr) external {
        numCalls["setSsr"]++;
        ssr = bound(ssr, RAY, 1000000021979553151239153027); // between 0% and 100% apy
        if (fail) {
            uint256 mod = 3 + users.length;
            failCallerIndex = bound(failCallerIndex, 0, mod - 1);
            address caller;
            if (failCallerIndex == 0) {
                caller = address(this); // this contract
            } else if (failCallerIndex == 1) {
                caller = admin; // admin
            } else if (failCallerIndex == 2) {
                caller = taker; // taker
            } else {
                caller = users[failCallerIndex - 3]; // user
            }
            vm.expectRevert(abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, SETTER_ROLE
            ));
            vm.prank(caller); proxy.setSsr(ssr);
            return;
        }
        vm.prank(ssrSetter); proxy.setSsr(ssr);
    }

    // function warp(uint256 secs) external {
    //     numCalls["warp"]++;
    //     secs = bound(secs, 0, 365 days);
    //     vm.warp(block.timestamp + secs);
    // }
    //
    // function drip() external {
    //     numCalls["drip"]++;
    //     proxy.drip();
    // }
    //
    // function deposit(uint256 assets) external {
    //     numCalls["deposit"]++;
    //     deal(address(usds), address(this), assets);
    //     usds.approve(address(proxy), assets);
    //     proxy.deposit(assets, address(this));
    // }
    //
    // function mint(uint256 shares) external {
    //     numCalls["mint"]++;
    //     deal(address(usds), address(this), proxy.previewMint(shares));
    //     usds.approve(address(proxy), proxy.previewMint(shares));
    //     proxy.mint(shares, address(this));
    // }
    //
    // function withdraw(uint256 assets) external {
    //     numCalls["withdraw"]++;
    //     assets = bound(assets, 0, proxy.previewWithdraw(proxy.balanceOf(address(this))));
    //     proxy.withdraw(assets, address(this), address(this));
    // }
    //
    // function withdrawAll() external {
    //     numCalls["withdrawAll"]++;
    //     proxy.withdraw(proxy.previewWithdraw(proxy.balanceOf(address(this))), address(this), address(this));
    // }
    //
    // function redeem(uint256 shares) external {
    //     numCalls["redeem"]++;
    //     shares = bound(shares, 0, proxy.balanceOf(address(this)));
    //     proxy.redeem(shares, address(this), address(this));
    // }
    //
    // function redeemAll() external {
    //     numCalls["redeemAll"]++;
    //     proxy.redeem(proxy.balanceOf(address(this)), address(this), address(this));
    // }
}

contract VaultInvariantsTest is Test {
    IERC20   asset;
    IVault   proxy;
    IVault   impl;
    VaultHandler handler;

    function setUp() public {
        handler = new VaultHandler();

         // uncomment and fill to only call specific functions
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = VaultHandler.setSsr.selector;
        // selectors[1] = VaultHandler.warp.selector;3       // selectors[2] = VaultHandler.drip.selector;
        // selectors[3] = VaultHandler.deposit.selector;
        // selectors[4] = VaultHandler.mint.selector;
        // selectors[5] = VaultHandler.withdraw.selector;
        // selectors[6] = VaultHandler.withdrawAll.selector;
        // selectors[7] = VaultHandler.redeem.selector;
        // selectors[8] = VaultHandler.redeemAll.selector;

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
