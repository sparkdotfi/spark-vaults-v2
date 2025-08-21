// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { UUPSUpgradeable } from "openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";

import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./TestBase.t.sol";

contract InvalidSparkVault1 {

    function proxiableUUID() external pure returns (bytes32) {
        return bytes32(0);
    }

}

contract InvalidSparkVault2 {}

contract SparkVaultUpgradeFailureTest is SparkVaultTestBase {

    function test_upgradeToAndCall_notAdmin() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        vault.upgradeToAndCall(makeAddr("newImplementation"), "");
    }

    function test_upgradeToAndCall_implementationUUIDNotSupported() public {
        address invalidImplementation = address(new InvalidSparkVault1());

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "UUPSUnsupportedProxiableUUID(bytes32)",
            bytes32(0)
        ));
        vault.upgradeToAndCall(invalidImplementation, "");
    }

    function test_upgradeToAndCall_implementationHasNoUUID() public {
        address invalidImplementation = address(new InvalidSparkVault2());

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "ERC1967InvalidImplementation(address)",
            invalidImplementation
        ));
        vault.upgradeToAndCall(invalidImplementation, "");
    }

}

contract SparkVaultUpgradeTest is SparkVaultTestBase {

    address user1 = makeAddr("user1");

    SparkVault newVaultImplementation;

    uint256 setVsrTimestamp;

    // Do some deposits to get some non-zero state
    function setUp() public override {
        super.setUp();

        newVaultImplementation = new SparkVault();

        vm.prank(admin);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        vm.prank(setter);
        vault.setVsr(FOUR_PCT_VSR);

        setVsrTimestamp = block.timestamp;

        deal(address(asset), user1, 1_000_000e6);

        vm.startPrank(user1);
        asset.approve(address(vault), 1_000_000e6);
        vault.deposit(1_000_000e6, user1);
        vm.stopPrank();

        skip(1 days);
    }

    // Check initial state and that no state changes
    function test_upgradeToAndCall() public {
        assertEq(vault.asset(),    address(asset));
        assertEq(vault.name(),     "Spark Savings USDC V2");
        assertEq(vault.symbol(),   "spUSDC");
        assertEq(vault.decimals(), 18);

        assertEq(vault.minVsr(), ONE_PCT_VSR);
        assertEq(vault.maxVsr(), FOUR_PCT_VSR);

        assertEq(uint256(vault.rho()), setVsrTimestamp);
        assertEq(uint256(vault.chi()), uint192(1e27));
        assertEq(uint256(vault.vsr()), FOUR_PCT_VSR);

        address[] memory defaultAdmins = vault.getRoleMembers(DEFAULT_ADMIN_ROLE);
        address[] memory setters       = vault.getRoleMembers(SETTER_ROLE);
        address[] memory takers        = vault.getRoleMembers(TAKER_ROLE);

        assertEq(defaultAdmins.length, 1);
        assertEq(setters.length,       1);
        assertEq(takers.length,        1);

        assertEq(defaultAdmins[0], admin);
        assertEq(setters[0],       setter);
        assertEq(takers[0],        taker);

        assertGt(vault.totalAssets(),   1_000_000e6);  // Some accrued interest
        assertGt(vault.assetsOf(user1), 1_000_000e6);

        assertEq(vault.totalSupply(),    1_000_000e6);
        assertEq(vault.balanceOf(user1), 1_000_000e6);

        uint256 totalAssets = vault.totalAssets();

        assertTrue(vault.getImplementation() != address(newVaultImplementation));

        vm.prank(admin);
        vault.upgradeToAndCall(address(newVaultImplementation), "");

        assertEq(vault.asset(),    address(asset));
        assertEq(vault.name(),     "Spark Savings USDC V2");
        assertEq(vault.symbol(),   "spUSDC");
        assertEq(vault.decimals(), 18);

        assertEq(vault.minVsr(), ONE_PCT_VSR);
        assertEq(vault.maxVsr(), FOUR_PCT_VSR);

        assertEq(uint256(vault.rho()), setVsrTimestamp);
        assertEq(uint256(vault.chi()), uint192(1e27));
        assertEq(uint256(vault.vsr()), FOUR_PCT_VSR);

        defaultAdmins = vault.getRoleMembers(DEFAULT_ADMIN_ROLE);
        setters       = vault.getRoleMembers(SETTER_ROLE);
        takers        = vault.getRoleMembers(TAKER_ROLE);

        assertEq(defaultAdmins.length, 1);
        assertEq(setters.length,       1);
        assertEq(takers.length,        1);

        assertEq(defaultAdmins[0], admin);
        assertEq(setters[0],       setter);
        assertEq(takers[0],        taker);

        assertEq(vault.totalAssets(),   totalAssets);
        assertEq(vault.assetsOf(user1), totalAssets);

        assertEq(vault.totalSupply(),    1_000_000e6);
        assertEq(vault.balanceOf(user1), 1_000_000e6);

        assertTrue(vault.getImplementation() == address(newVaultImplementation));
    }

}
