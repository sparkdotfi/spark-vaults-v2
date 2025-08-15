// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Test }      from "forge-std/Test.sol";
import { MockERC20 } from "forge-std/mocks/MockERC20.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Vault } from "../src/Vault.sol";

contract VaultUnitTestBase is Test {

    uint256 constant ONE_PCT_SSR  = 1.000000000315522921573372069e27;
    uint256 constant FOUR_PCT_SSR = 1.000000001243680656318820312e27;
    uint256 constant MAX_SSR      = 1.000000021979553151239153027e27;  // 100% APY

    address admin  = makeAddr("admin");
    address setter = makeAddr("setter");
    address taker  = makeAddr("taker");

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 TAKER_ROLE         = keccak256("TAKER_ROLE");

    MockERC20 usdc;
    Vault     vault;

    function setUp() public virtual {
        usdc = new MockERC20();

        address vaultImpl = address(new Vault());

        vault = Vault(address(new ERC1967Proxy(vaultImpl, "")));

        vault.initialize(address(usdc), "Spark Savings USDC V2", "spUSDC", admin);

        vm.startPrank(admin);
        vault.grantRole(SETTER_ROLE, setter);
        vault.grantRole(TAKER_ROLE,  taker);
        vm.stopPrank();
    }

}
