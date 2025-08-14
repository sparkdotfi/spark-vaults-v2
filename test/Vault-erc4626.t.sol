// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021 Dai Foundation
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

pragma solidity 0.8.29;

import { ERC4626Test, StdStorage, stdStorage, console2 as console } from "erc4626-tests/ERC4626.test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20Mock    } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import { Vault } from "src/Vault.sol";

contract VautERC4626Test is ERC4626Test {

    using stdStorage for StdStorage;

    Vault vault;
    ERC20Mock asset;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 constant TAKER_ROLE         = keccak256("TAKER_ROLE");

    address admin  = makeAddr("admin");
    address setter = makeAddr("setter");
    address taker  = makeAddr("taker");

    uint256 constant private RAY = 10**27;

    function setUp() public override {
        // Set up the asset
        asset = new ERC20Mock();
        vault = Vault(
            address(new ERC1967Proxy(
                address(new Vault()),
                abi.encodeCall(
                    Vault.initialize,
                    (address(asset), "Spark USDS", "spUSDS", admin)
                )
            ))
        );

        vm.prank(admin); vault.grantRole(SETTER_ROLE, setter);
        vm.prank(admin); vault.grantRole(TAKER_ROLE, taker);

        vm.prank(setter); vault.setSsr(1000000001547125957863212448);
        vm.warp(100 days);
        vault.drip();

        assertGt(vault.chi(), RAY);

        _underlying_ = address(asset);
        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }

    // setup initial vault state
    function setUpVault(Init memory init) public override {
        for (uint256 i = 0; i < N; i++) {
            console.log("A");
            init.share[i] %= 1_000_000_000 ether;
            init.asset[i] %= 1_000_000_000 ether;
            vm.assume(init.user[i] != address(0) && init.user[i] != address(vault));
        }
        super.setUpVault(init);
    }

    // setup initial yield
    function setUpYield(Init memory init) public override {
        vm.assume(init.yield >= 0);
        init.yield %= 1_000_000_000 ether;
        uint256 gain = uint256(init.yield);

        uint256 supply = vault.totalSupply();
        if (supply > 0) {
            uint256 nChi = gain * RAY / supply + vault.chi();
            // uint256 chiRho = (block.timestamp << 192) + nChi;
            uint256 chiRho = (nChi << 64) + block.timestamp;
            vm.store(
                address(vault),
                bytes32(uint256(3)),
                bytes32(chiRho)
            );
            assertEq(uint256(vault.rho()), block.timestamp);
            assertEq(uint256(vault.chi()), nChi);
        }
    }

}
