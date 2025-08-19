
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./TestBase.t.sol";

contract SparkVaultInitializeSuccessTests is SparkVaultTestBase {

    // NOTE: This cannot be part of SparkVaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant internal RAY = 1e27;

    function test_initialize() public {
        // This is from OpenZeppelin's Initializable.sol, which is used in SparkVault.
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

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
        assertEq(vault.asset(), address(0));
        assertEq(vault.name(), "");
        assertEq(vault.symbol(), "");
        assertFalse(vault.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertEq(vault.chi(), 0);
        assertEq(vault.rho(), 0);
        assertEq(vault.ssr(), 0);
        assertEq(vault.minSsr(), 0);
        assertEq(vault.maxSsr(), 0);

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

        assertEq(vault.asset(), address(asset));
        assertEq(vault.name(), "Spark Savings USDC V2");
        assertEq(vault.symbol(), "spUSDC");
        assertTrue(vault.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertEq(vault.chi(), RAY);
        assertEq(vault.rho(), uint64(block.timestamp));
        assertEq(vault.ssr(), RAY);
        assertEq(vault.minSsr(), RAY);
        assertEq(vault.maxSsr(), RAY);
    }

}

contract SparkVaultInitializeFailureTests is SparkVaultInitializeSuccessTests {

    function test_initialize_alreadyInitialized() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        vault.initialize(
            address(asset),
            "Spark Savings USDC V2",
            "spUSDC",
            admin
        );
    }

}

