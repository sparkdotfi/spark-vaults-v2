// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.29;

import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Vault } from "src/Vault.sol";

import { VaultTestBase } from "./TestBase.t.sol";

contract VautERC4626Test is ERC4626Test, VaultTestBase {

    // @note This cannot be part of VaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant internal RAY = 1e27;

    function setUp() public override( ERC4626Test, VaultTestBase ) {
        super.setUp();

        // Set ssr, warp time and drip
        vm.prank(setter); vault.setSsr(1000000001547125957863212448);
        vm.warp(100 days);
        vault.drip();

        // chi should increase
        assertGt(vault.chi(), RAY);

        // Initialize the ERC4626 test
        _underlying_     = address(asset);
        _vault_          = address(vault);
        _delta_          = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }

    // setup initial vault state
    function setUpVault(Init memory init) public override {
        // Make assumptions about init
        for (uint256 i = 0; i < N; i++) {
            init.share[i] = _bound(init.share[i], 0, 1_000_000_000 ether - 1);
            init.share[i] = _bound(init.asset[i], 0, 1_000_000_000 ether - 1);
            vm.assume(init.user[i] != address(0) && init.user[i] != address(vault));
        }
        // Call the parent to set up the vault
        super.setUpVault(init);
    }

    // setup initial yield
    function setUpYield(Init memory init) public override {
        vm.assume(init.yield >= 0);
        init.yield = _bound(init.yield, 0, 1_000_000_000 ether - 1);
        uint256 gain = uint256(init.yield);

        uint256 supply = vault.totalSupply();

        if (supply > 0) {
            uint256 nChi = gain * RAY / supply + vault.chi();
            uint256 chiRho = (nChi << 64) + block.timestamp;
            // Directly store chi and rho in storage
            // They are currently packed together at slot #3 in storage
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
