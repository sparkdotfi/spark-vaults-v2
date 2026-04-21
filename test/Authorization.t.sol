// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./TestBase.t.sol";

import { ISparkVault } from "../src/ISparkVault.sol";

contract SparkVaultSetVsrBoundsFailureTests is SparkVaultTestBase {

    function test_setVsrBounds_notAdmin() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        vault.setVsrBounds(1e27, FOUR_PCT_VSR);
    }

    function test_setVsrBounds_belowRayBoundary() public {
        vm.startPrank(admin);
        vm.expectRevert("SparkVault/vsr-too-low");
        vault.setVsrBounds(1e27 - 1, FOUR_PCT_VSR);

        vault.setVsrBounds(1e27, FOUR_PCT_VSR);
    }

    function test_setVsrBounds_aboveMaxVsrBoundary() public {
        vm.startPrank(admin);
        vm.expectRevert("SparkVault/vsr-too-high");
        vault.setVsrBounds(1e27, MAX_VSR + 1);

        vault.setVsrBounds(1e27, MAX_VSR);
    }

    function test_setVsrBounds_minVsrGtMaxVsrBoundary() public {
        vm.startPrank(admin);
        vm.expectRevert("SparkVault/min-vsr-gt-max-vsr");
        vault.setVsrBounds(FOUR_PCT_VSR + 1, FOUR_PCT_VSR);

        vault.setVsrBounds(FOUR_PCT_VSR, FOUR_PCT_VSR);
    }

}

contract SparkVaultSetVsrBoundsSuccessTests is SparkVaultTestBase {

    event VsrBoundsSet(uint256 oldMinVsr, uint256 oldMaxVsr, uint256 newMinVsr, uint256 newMaxVsr);

    function test_setVsrBounds() public {
        assertEq(vault.minVsr(), 1e27);
        assertEq(vault.maxVsr(), 1e27);

        vm.startPrank(admin);
        vm.expectEmit(address(vault));
        emit VsrBoundsSet(1e27, 1e27, ONE_PCT_VSR, FOUR_PCT_VSR);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        assertEq(vault.minVsr(), ONE_PCT_VSR);
        assertEq(vault.maxVsr(), FOUR_PCT_VSR);
    }

}

contract SparkVaultGrantRoleFailureTests is SparkVaultTestBase {

    function test_grantRole_notAdmin() public {
        bytes32[] memory roles = new bytes32[](3);
        roles[0] = DEFAULT_ADMIN_ROLE;
        roles[1] = SETTER_ROLE;
        roles[2] = TAKER_ROLE;

        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            vm.expectRevert(abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                DEFAULT_ADMIN_ROLE
            ));
            vault.grantRole(role, address(0x1234));
        }
    }

}

contract SparkVaultGrantRoleSuccessTests is SparkVaultTestBase {

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function test_grantRole() public {
        bytes32[] memory roles = new bytes32[](3);
        roles[0] = DEFAULT_ADMIN_ROLE;
        roles[1] = SETTER_ROLE;
        roles[2] = TAKER_ROLE;

        // admin (DEFAULT_ADMIN_ROLE) should be allowed to grant DEFAULT_ADMIN_ROLE, SETTER_ROLE,
        // TAKER_ROLE.
        vm.startPrank(admin);
        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            assertFalse(vault.hasRole(role, address(0x1234)));

            vm.expectEmit(address(vault));
            emit RoleGranted(role, address(0x1234), admin);
            vault.grantRole(role, address(0x1234));

            assertTrue(vault.hasRole(role, address(0x1234)));

            // Check role admin hasn't changed
            assertTrue(vault.getRoleAdmin(role) == DEFAULT_ADMIN_ROLE);
        }

        // Check that our admin in still DEFAULT_ADMIN_ROLE
        assertTrue(vault.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

}

contract SparkVaultRevokeRoleFailureTests is SparkVaultTestBase {

    function test_revokeRole_notAdmin() public {
        bytes32[] memory roles = new bytes32[](3);
        roles[0] = DEFAULT_ADMIN_ROLE;
        roles[1] = SETTER_ROLE;
        roles[2] = TAKER_ROLE;

        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];
            vm.expectRevert(abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                address(this),
                DEFAULT_ADMIN_ROLE
            ));
            vault.revokeRole(role, address(0x1234));
        }
    }

}

contract SparkVaultRevokeRoleSuccessTests is SparkVaultGrantRoleSuccessTests {

    function test_revokeRole() public {
        bytes32[] memory roles = new bytes32[](3);
        roles[0] = DEFAULT_ADMIN_ROLE;
        roles[1] = SETTER_ROLE;
        roles[2] = TAKER_ROLE;

        // First, call test_grantRole()
        test_grantRole();

        vm.startPrank(admin);
        for (uint256 i = 0; i < roles.length; i++) {
            bytes32 role = roles[i];

            assertTrue(vault.hasRole(role, address(0x1234)));

            vm.expectEmit(address(vault));
            emit RoleRevoked(role, address(0x1234), admin);
            vault.revokeRole(role, address(0x1234));

            assertFalse(vault.hasRole(role, address(0x1234)));

            // Check role admin hasn't changed
            assertTrue(vault.getRoleAdmin(role) == DEFAULT_ADMIN_ROLE);
        }

        // Check that our admin in still DEFAULT_ADMIN_ROLE
        assertTrue(vault.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

}

contract SparkVaultSetDepositCapFailureTests is SparkVaultTestBase {

    function test_setDepositCap_notAdmin() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        vault.setDepositCap(2_000_000e6);
    }

}

contract SparkVaultSetDepositCapSuccessTests is SparkVaultTestBase {

    event DepositCapSet(uint256 oldCap, uint256 newCap);

    function test_setDepositCap() public {
        assertEq(vault.depositCap(), 1_000_000e6);

        vm.startPrank(admin);
        vm.expectEmit(address(vault));
        emit DepositCapSet(1_000_000e6, 2_000_000e6);
        vault.setDepositCap(2_000_000e6);

        assertEq(vault.depositCap(), 2_000_000e6);

        vm.expectEmit(address(vault));
        emit DepositCapSet(2_000_000e6, type(uint256).max);
        vault.setDepositCap(type(uint256).max);

        assertEq(vault.depositCap(), type(uint256).max);

        vm.expectEmit(address(vault));
        emit DepositCapSet(type(uint256).max, 0);
        vault.setDepositCap(0);

        assertEq(vault.depositCap(), 0);

        address randomUser = makeAddr("randomUser");
        vm.startPrank(randomUser);
        deal(address(asset), randomUser, 1);
        asset.approve(address(vault), 1);
        vm.expectRevert("SparkVault/deposit-cap-exceeded");
        vault.deposit(1, randomUser);
        vm.stopPrank();
    }

}

contract SparkVaultSetTakerMintCapFailureTests is SparkVaultTestBase {

    address unauthorized = makeAddr("unauthorized");

    function test_setTakerMintCap_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            DEFAULT_ADMIN_ROLE
        ));

        vm.prank(unauthorized);
        vault.setTakerMintCap(1_000_000e6);
    }

}

contract SparkVaultSetTakerMintCapSuccessTests is SparkVaultTestBase {

    function test_setTakerMintCap() external {
        assertEq(vault.takerMintCap(), 10_000_000e6);

        vm.expectEmit(address(vault));
        emit ISparkVault.TakerMintCapSet(10_000_000e6, 100_000_000e6);

        vm.prank(admin);
        vault.setTakerMintCap(100_000_000e6);  // 100M shares

        assertEq(vault.takerMintCap(), 100_000_000e6);  // 100M shares

        vm.expectEmit(address(vault));
        emit ISparkVault.TakerMintCapSet(100_000_000e6, type(uint256).max);

        vm.prank(admin);
        vault.setTakerMintCap(type(uint256).max);

        assertEq(vault.takerMintCap(), type(uint256).max);
    }

}

contract SparkVaultSetVsrFailureTests is SparkVaultTestBase {

    function test_setVsr_notSetter() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            SETTER_ROLE
        ));
        vault.setVsr(ONE_PCT_VSR);
    }

    function test_setVsr_belowMinVsrBoundary() public {
        vm.startPrank(setter);
        vm.expectRevert("SparkVault/vsr-too-low");
        vault.setVsr(1e27 - 1);

        vault.setVsr(1e27);  // Min is 1e27 on deployment

        vm.stopPrank();

        vm.prank(admin);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        vm.startPrank(setter);
        vm.expectRevert("SparkVault/vsr-too-low");
        vault.setVsr(ONE_PCT_VSR - 1);

        vault.setVsr(ONE_PCT_VSR);
    }

    function test_setVsr_aboveMaxVsrBoundary() public {
        vm.startPrank(setter);
        vm.expectRevert("SparkVault/vsr-too-high");
        vault.setVsr(1e27 + 1);  // Can't set VSR until admin sets bounds

        vault.setVsr(1e27);  // Max is 1e27 on deployment

        vm.stopPrank();

        vm.prank(admin);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        vm.startPrank(setter);
        vm.expectRevert("SparkVault/vsr-too-high");
        vault.setVsr(FOUR_PCT_VSR + 1);

        vault.setVsr(FOUR_PCT_VSR);
    }

}

contract SparkVaultSetVsrSuccessTests is SparkVaultTestBase {

    event Drip(uint256 nChi, uint256 diff);
    event VsrSet(address sender, uint256 oldVsr, uint256 newVsr);

    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        vault.setVsrBounds(1e27, FOUR_PCT_VSR);
    }

    function test_setVsr() public {
        uint256 deployTimestamp = block.timestamp;

        skip(10 days);

        assertEq(uint256(vault.chi()), 1e27);
        assertEq(uint256(vault.rho()), deployTimestamp);
        assertEq(uint256(vault.vsr()), 1e27);

        vm.prank(setter);
        vm.expectEmit(address(vault));
        emit Drip(1e27, 0);
        emit VsrSet(setter, 1e27, FOUR_PCT_VSR);
        vault.setVsr(FOUR_PCT_VSR);

        assertEq(uint256(vault.chi()), 1e27);
        assertEq(uint256(vault.rho()), block.timestamp);
        assertEq(uint256(vault.vsr()), FOUR_PCT_VSR);

        assertEq(vault.nowChi(), 1e27);

        skip(10 days);

        assertGt(vault.nowChi(), 1e27);
    }

}

contract SparkVaultTakeFailureTests is SparkVaultTestBase {

    function test_take_notTaker() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            TAKER_ROLE
        ));
        vault.take(1_000_000e6);
    }

    function test_take_insufficientBalanceBoundary() public {
        deal(address(asset), address(vault), 1_000_000e6);

        vm.startPrank(taker);
        vm.expectRevert();
        vault.take(1_000_000e6 + 1);

        vault.take(1_000_000e6);
    }

}

contract SparkVaultTakeSuccessTests is SparkVaultTestBase {

    function test_take() public {
        deal(address(asset), address(vault), 1_000_000e6);

        assertEq(asset.balanceOf(address(vault)), 1_000_000e6);
        assertEq(asset.balanceOf(taker),          0);

        vm.prank(taker);
        vault.take(1_000_000e6);

        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(taker),          1_000_000e6);
    }

}

contract SparkVaultTakerMintFailureTests is SparkVaultTestBase {

    address unauthorized = makeAddr("unauthorized");

    function test_takerMint_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            TAKER_ROLE
        ));

        vm.prank(unauthorized);
        vault.takerMint(1_000_000e6);
    }

    function test_takerMint_capExceededBoundary() external {
        vm.prank(taker);
        vm.expectRevert("SparkVault/taker-mint-cap-exceeded");
        vault.takerMint(10_000_000e6 + 1);

        vm.prank(taker);
        vault.takerMint(10_000_000e6);
    }

}

contract SparkVaultTakerMintSuccessTests is SparkVaultTestBase {

    function test_takerMint() external {
        assertEq(vault.chi(),                     1e27);
        assertEq(vault.rho(),                     block.timestamp);
        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(taker),          0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(taker),          0);

        skip(1 days);

        vm.expectEmit(address(vault));
        emit ISparkVault.Drip(1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkVault.TakerMint(taker, 1_000_000e6);

        vm.expectEmit(address(vault));
        emit IERC20.Transfer(address(0), taker, 1_000_000e6);

        vm.prank(taker);
        vault.takerMint(1_000_000e6);

        assertEq(vault.chi(),                     1e27);
        assertEq(vault.rho(),                     block.timestamp);
        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(taker),          1_000_000e6);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(taker),          0);
    }

    function test_takerMint_doesNotDiluteUsers() external {
        address user        = makeAddr("user");
        uint256 userDeposit = 500_000e6;

        // User deposits 500k assets

        deal(address(asset), user, userDeposit);

        vm.startPrank(user);

        asset.approve(address(vault), userDeposit);

        vault.deposit(userDeposit, user);

        vm.stopPrank();

        uint256 userSharesBefore  = vault.balanceOf(user);
        uint256 userAssetsBefore  = vault.assetsOf(user);
        uint256 totalAssetsBefore = vault.totalAssets();

        uint256 mintShares = 2_000_000e6;

        // Taker mints 2M shares

        vm.prank(taker);
        vault.takerMint(mintShares);

        // User's share balance and asset claim are untouched by the Taker mint
        assertEq(vault.balanceOf(user), userSharesBefore);
        assertEq(vault.assetsOf(user),  userAssetsBefore);

        // totalAssets grows by exactly the Taker's new claim (non-dilutive)
        assertEq(vault.totalAssets(), totalAssetsBefore + mintShares * vault.nowChi() / 1e27);
    }

    function test_takerMint_bypassesDepositCap() external {
        address user = makeAddr("user");
        uint256 cap  = vault.depositCap();

        // Fill the deposit cap with a user deposit

        deal(address(asset), user, cap);

        vm.startPrank(user);

        asset.approve(address(vault), cap);

        vault.deposit(cap, user);

        vm.stopPrank();

        // Confirm the cap is exhausted: another 1 wei deposit reverts
        address otherUser = makeAddr("otherUser");

        deal(address(asset), otherUser, 1);

        vm.startPrank(otherUser);

        asset.approve(address(vault), 1);

        vm.expectRevert("SparkVault/deposit-cap-exceeded");
        vault.deposit(1, otherUser);

        vm.stopPrank();

        // Taker can still mint, even though totalAssets is already at the cap
        vm.prank(taker);
        vault.takerMint(5_000_000e6);

        assertEq(vault.balanceOf(taker), 5_000_000e6);
        assertGt(vault.totalAssets(),    vault.depositCap());
    }

}

contract SparkVaultTakerBurnFailureTests is SparkVaultTestBase {

    address unauthorized = makeAddr("unauthorized");

    function test_takerBurn_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            unauthorized,
            TAKER_ROLE
        ));

        vm.prank(unauthorized);
        vault.takerBurn(1_000_000e6);
    }

    function test_takerBurn_insufficientBalanceBoundary() external {
        vm.prank(taker);
        vault.takerMint(1_000_000e6);

        vm.expectRevert("SparkVault/insufficient-balance");
        vm.prank(taker);
        vault.takerBurn(1_000_000e6 + 1);

        vm.prank(taker);
        vault.takerBurn(1_000_000e6);
    }

}

contract SparkVaultTakerBurnSuccessTests is SparkVaultTestBase {

    function test_takerBurn() external {
        vm.prank(taker);
        vault.takerMint(1_000_000e6);

        assertEq(vault.chi(),                     1e27);
        assertEq(vault.rho(),                     block.timestamp);
        assertEq(vault.totalSupply(),             1_000_000e6);
        assertEq(vault.balanceOf(taker),          1_000_000e6);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(taker),          0);

        skip(1 days);

        vm.expectEmit(address(vault));
        emit ISparkVault.Drip(1e27, 0);

        vm.expectEmit(address(vault));
        emit IERC20.Transfer(taker, address(0), 1_000_000e6);

        vm.expectEmit(address(vault));
        emit ISparkVault.TakerBurn(taker, 1_000_000e6);

        vm.prank(taker);
        vault.takerBurn(1_000_000e6);

        assertEq(vault.chi(),                     1e27);
        assertEq(vault.rho(),                     block.timestamp);
        assertEq(vault.totalSupply(),             0);
        assertEq(vault.balanceOf(taker),          0);
        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(taker),          0);
    }

    function test_takerBurn_doesNotMoveAssets() external {
        address user        = makeAddr("user");
        uint256 userDeposit = 500_000e6;

        // User deposits 500k assets

        deal(address(asset), user, userDeposit);

        vm.startPrank(user);

        asset.approve(address(vault), userDeposit);

        vault.deposit(userDeposit, user);

        vm.stopPrank();

        uint256 mintShares = 1_000_000e6;

        // Taker mints 1M shares

        vm.prank(taker);
        vault.takerMint(mintShares);

        uint256 vaultAssetsBefore  = asset.balanceOf(address(vault));
        uint256 takerAssetsBefore  = asset.balanceOf(taker);
        uint256 userAssetsOfBefore = vault.assetsOf(user);

        // Taker burns 500k shares

        vm.prank(taker);
        vault.takerBurn(mintShares / 2);

        // No asset movement in either direction
        assertEq(asset.balanceOf(address(vault)), vaultAssetsBefore);
        assertEq(asset.balanceOf(taker),          takerAssetsBefore);

        // Users' redeemable claim is untouched
        assertEq(vault.assetsOf(user), userAssetsOfBefore);
    }

    function test_takerMintBurn_roundTrip() external {
        uint256 chiBefore         = vault.chi();
        uint256 rhoBefore         = vault.rho();
        uint256 totalSupplyBefore = vault.totalSupply();
        uint256 balanceBefore     = vault.balanceOf(taker);
        uint256 vaultAssetsBefore = asset.balanceOf(address(vault));

        uint256 shares = 2_500_000e6;

        vm.prank(taker);
        vault.takerMint(shares);

        vm.prank(taker);
        vault.takerBurn(shares);

        // Full round trip leaves every tracked field identical to pre-call state
        assertEq(vault.chi(),                     chiBefore);
        assertEq(vault.rho(),                     rhoBefore);
        assertEq(vault.totalSupply(),             totalSupplyBefore);
        assertEq(vault.balanceOf(taker),          balanceBefore);
        assertEq(asset.balanceOf(address(vault)), vaultAssetsBefore);
    }

}
