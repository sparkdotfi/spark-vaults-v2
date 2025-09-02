// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "./TestBase.t.sol";

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
