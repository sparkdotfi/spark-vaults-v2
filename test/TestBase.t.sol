// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock as MockERC20 } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { ERC1967Proxy }           from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SparkVault } from "../src/SparkVault.sol";

contract SparkVaultTestBase is Test {

    uint256 constant ONE_PCT_SSR  = 1.000000000315522921573372069e27;
    uint256 constant FOUR_PCT_SSR = 1.000000001243680656318820312e27;
    uint256 constant MAX_SSR      = 1.000000021979553151239153027e27;  // 100% APY

    address admin  = makeAddr("admin");
    address setter = makeAddr("setter");
    address taker  = makeAddr("taker");

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 TAKER_ROLE         = keccak256("TAKER_ROLE");

    MockERC20  asset;
    SparkVault vault;

    function setUp() public virtual {
        asset = new MockERC20();

        vault = SparkVault(
            address(new ERC1967Proxy(
                address(new SparkVault()),
                abi.encodeCall(
                    SparkVault.initialize,
                    (address(asset), "Spark Savings USDC V2", "spUSDC", admin)
                )
            ))
        );

        vm.startPrank(admin);
        vault.grantRole(SETTER_ROLE, setter);
        vault.grantRole(TAKER_ROLE,  taker);
        vm.stopPrank();
    }

}

contract SparkVaultMiscellaneousTests is SparkVaultTestBase {
        // asset  = asset_;
        // name   = name_;
        // symbol = symbol_;
        //
        // _grantRole(DEFAULT_ADMIN_ROLE, admin);
        //
        // chi = uint192(RAY);
        // rho = uint64(block.timestamp);
        // ssr = RAY;
        //
        // minSsr = RAY;
        // maxSsr = RAY;
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    function test_initialize() public {
        // >> Don't use the vault created by `setUp()`, create our own here:
        vault = SparkVault(
            address(new ERC1967Proxy(
                address(new SparkVault()),
                ""
            ))
        );
        // >> Assert that the vault is not initialized
        assertEq(
            vm.load(
                address(vault),
                INITIALIZABLE_STORAGE
            ),
            bytes32(0)
        );

        // >> Action
        vault.initialize(
            address(asset),
            "Spark Savings USDC V2",
            "spUSDC",
            admin
        );

        // >> Assert that the vault has been initialized
        assertEq(
            vm.load(
                address(vault),
                INITIALIZABLE_STORAGE
            ),
            bytes32(uint256(1))
        );
    }

}

