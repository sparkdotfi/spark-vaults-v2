// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./TestBase.t.sol";

<<<<<<< HEAD
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
=======
contract SparkVaultInitializeFailureTests is SparkVaultTestBase {
>>>>>>> master

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

<<<<<<< HEAD
contract SparkVaultGettersTests is SparkVaultTestBase {
=======
contract SparkVaultInitializeSuccessTests is SparkVaultTestBase {
>>>>>>> master

    // NOTE: This cannot be part of SparkVaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant internal RAY = 1e27;

<<<<<<< HEAD
    function test_getters() public {
        // > Test `assetsOf(address)`, `assetsOutstanding()`, `nowChi()`
        address user1 = makeAddr("user1");
        deal(address(asset), user1, 1_000_000e6);

        // >> Prank
=======
    function test_initialize() public {
        // This is from OpenZeppelin's Initializable.sol, which is used in SparkVault.
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

        // Overwrite vault deployment from setUp() to test initialization
        vault = SparkVault(
            address(new ERC1967Proxy(
                address(new SparkVault()),
                ""
            ))
        );

        // Assert that the vault is not initialized
        assertEq(
            vm.load(
                address(vault),
                INITIALIZABLE_STORAGE
            ),
            bytes32(0)
        );
        assertEq(vault.asset(),  address(0));
        assertEq(vault.name(),   "");
        assertEq(vault.symbol(), "");
        assertEq(vault.chi(),    0);
        assertEq(vault.rho(),    0);
        assertEq(vault.ssr(),    0);
        assertEq(vault.minSsr(), 0);
        assertEq(vault.maxSsr(), 0);

        assertFalse(vault.hasRole(DEFAULT_ADMIN_ROLE, admin));

        vault.initialize(
            address(asset),
            "Spark Savings USDC V2",
            "spUSDC",
            admin
        );

        // Assert that the vault has been initialized
        assertEq(
            vm.load(
                address(vault),
                INITIALIZABLE_STORAGE
            ),
            bytes32(uint256(1))
        );

        assertEq(vault.asset(),  address(asset));
        assertEq(vault.name(),   "Spark Savings USDC V2");
        assertEq(vault.symbol(), "spUSDC");
        assertEq(vault.chi(),     RAY);
        assertEq(vault.rho(),     uint64(block.timestamp));
        assertEq(vault.ssr(),     RAY);
        assertEq(vault.minSsr(),  RAY);
        assertEq(vault.maxSsr(),  RAY);

        assertTrue(vault.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

}

contract SparkVaultConvenienceViewFunctionTests is SparkVaultTestBase {

    // NOTE: This cannot be part of SparkVaultTestBase, because that is used in a contract where DssTest
    // is also used (and that also defines RAY).
    uint256 constant internal RAY = 1e27;

    address user1 = makeAddr("user1");

    function test_convenienceViewFunctions() public {
        // Test `assetsOf(address)`, `assetsOutstanding()`, `nowChi()`
        deal(address(asset), user1, 1_000_000e6);

>>>>>>> master
        vm.startPrank(user1);
        asset.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, user1);
        vm.stopPrank();

        assertEq(vault.assetsOutstanding(), 0);
<<<<<<< HEAD
        assertEq(vault.assetsOf(user1), 1_000_000e6);
        assertEq(vault.nowChi(), RAY);
=======
        assertEq(vault.assetsOf(user1),     1_000_000e6);
        assertEq(vault.nowChi(),            RAY);
>>>>>>> master

        vm.startPrank(admin);
        vault.setSsrBounds(1e27, vault.MAX_SSR());
        vm.startPrank(setter);
<<<<<<< HEAD
=======

>>>>>>> master
        // 5% APY:
        // ❯ bc -l <<< 'scale=27; e( l(1.05)/(60 * 60 * 24 * 365) )'
        // 1.000000001547125957863212448
        vault.setSsr(1.000000001547125957863212448e27);
        vm.stopPrank();

<<<<<<< HEAD
        // >> Action
        vm.startPrank(taker);
        vault.take(500_000e6);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 1_000_000e6);
        assertEq(vault.assetsOutstanding(), 500_000e6);
        assertEq(vault.assetsOf(user1), 1_000_000e6);
        assertEq(vault.nowChi(), RAY);

        // >> Action
        vm.warp(1 hours);

        // >> Even without calling drip(), these functions return new values (they all use `nowChi()`
        // internally):
        assertEq(vault.assetsOutstanding(), 500_005.568121e6);
        assertEq(vault.assetsOf(user1), 1_000_005.568121e6);
        assertEq(vault.nowChi(), 1.000005568121819975177325790e27);

        // >> Action
        vault.drip();

        // >> After calling drip(), the values should be the same:
        assertEq(vault.assetsOutstanding(), 500_005.568121e6);
        assertEq(vault.assetsOf(user1), 1_000_005.568121e6);
        assertEq(vault.nowChi(), 1.000005568121819975177325790e27);
=======
        vm.prank(taker);
        vault.take(500_000e6);

        assertEq(vault.totalAssets(),       1_000_000e6);
        assertEq(vault.assetsOutstanding(), 500_000e6);
        assertEq(vault.assetsOf(user1),     1_000_000e6);
        assertEq(vault.nowChi(),            RAY);

        vm.warp(1 hours);

        // Even without calling drip(), these functions return new values (they all use `nowChi()`
        // internally):
        assertEq(vault.assetsOutstanding(), 500_005.568121e6);
        assertEq(vault.assetsOf(user1),     1_000_005.568121e6);
        assertEq(vault.nowChi(),            1.000005568121819975177325790e27);

        vault.drip();

        // After calling drip(), the values should be the same:
        assertEq(vault.assetsOutstanding(), 500_005.568121e6);
        assertEq(vault.assetsOf(user1),     1_000_005.568121e6);
        assertEq(vault.nowChi(),            1.000005568121819975177325790e27);
    }

function test_assetsOutstanding_returnsZeroOverLiquidityBoundary() public {
        vm.prank(admin);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);

        vm.prank(setter);
        vault.setSsr(FOUR_PCT_SSR);

        deal(address(asset), user1, 1_000_000e6);

        vm.startPrank(user1);
        asset.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, user1);
        vm.stopPrank();

        assertEq(vault.assetsOutstanding(), 0);

        skip(1 days);

        assertEq(vault.assetsOutstanding(), 107.459782e6);

        uint256 totalAssets = vault.totalAssets();

        assertEq(totalAssets, 1_000_107.459782e6);

        deal(address(asset), address(vault), totalAssets - 1);

        // Should return 1
        assertEq(vault.assetsOutstanding(), 1);

        deal(address(asset), address(vault), totalAssets);

        // Should return 0 when liquidity == totalAssets
        assertEq(vault.assetsOutstanding(), 0);

        deal(address(asset), address(vault), totalAssets + 1);

        // Should return 0 when liquidity > totalAssets
        assertEq(vault.assetsOutstanding(), 0);
>>>>>>> master
    }

}

