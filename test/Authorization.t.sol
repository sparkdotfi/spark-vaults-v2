// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./TestBase.t.sol";

contract SparkVaultSetSsrBoundsFailureTests is SparkVaultTestBase {

    function test_setSsrBounds_notAdmin() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        vault.setSsrBounds(1e27, FOUR_PCT_SSR);
    }

    function test_setSsrBounds_belowRayBoundary() public {
        vm.startPrank(admin);
        vm.expectRevert("Vault/ssr-too-low");
        vault.setSsrBounds(1e27 - 1, FOUR_PCT_SSR);

        vault.setSsrBounds(1e27, FOUR_PCT_SSR);
    }

    function test_setSsrBounds_aboveMaxSsrBoundary() public {
        vm.startPrank(admin);
        vm.expectRevert("Vault/ssr-too-high");
        vault.setSsrBounds(1e27, MAX_SSR + 1);

        vault.setSsrBounds(1e27, MAX_SSR);
    }

}

contract SparkVaultSetSsrBoundsSuccessTests is SparkVaultTestBase {

    event SsrBoundsSet(uint256 oldMinSsr, uint256 oldMaxSsr, uint256 newMinSsr, uint256 newMaxSsr);

    function test_setSsrBounds() public {
        assertEq(vault.minSsr(), 1e27);
        assertEq(vault.maxSsr(), 1e27);

        vm.startPrank(admin);
        vm.expectEmit(address(vault));
        emit SsrBoundsSet(1e27, 1e27, ONE_PCT_SSR, FOUR_PCT_SSR);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);

        assertEq(vault.minSsr(), ONE_PCT_SSR);
        assertEq(vault.maxSsr(), FOUR_PCT_SSR);
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

contract SparkVaultSetSsrFailureTests is SparkVaultTestBase {

    function test_setSsr_notSetter() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            SETTER_ROLE
        ));
        vault.setSsr(ONE_PCT_SSR);
    }

    function test_setSsr_belowMinSsrBoundary() public {
        vm.startPrank(setter);
        vm.expectRevert("Vault/ssr-too-low");
        vault.setSsr(1e27 - 1);

        vault.setSsr(1e27);  // Min is 1e27 on deployment

        vm.stopPrank();

        vm.prank(admin);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);

        vm.startPrank(setter);
        vm.expectRevert("Vault/ssr-too-low");
        vault.setSsr(ONE_PCT_SSR - 1);

        vault.setSsr(ONE_PCT_SSR);
    }

    function test_setSsr_aboveMaxSsrBoundary() public {
        vm.startPrank(setter);
        vm.expectRevert("Vault/ssr-too-high");
        vault.setSsr(1e27 + 1);  // Can't set SSR until admin sets bounds

        vault.setSsr(1e27);  // Max is 1e27 on deployment

        vm.stopPrank();

        vm.prank(admin);
        vault.setSsrBounds(ONE_PCT_SSR, FOUR_PCT_SSR);

        vm.startPrank(setter);
        vm.expectRevert("Vault/ssr-too-high");
        vault.setSsr(FOUR_PCT_SSR + 1);

        vault.setSsr(FOUR_PCT_SSR);
    }

}

contract SparkVaultSetSsrSuccessTests is SparkVaultTestBase {

    event Drip(uint256 nChi, uint256 diff);
    event SsrSet(address sender, uint256 oldSsr, uint256 newSsr);

    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        vault.setSsrBounds(1e27, FOUR_PCT_SSR);
    }

    function test_setSsr() public {
        uint256 deployTimestamp = block.timestamp;

        skip(10 days);

        assertEq(uint256(vault.chi()), 1e27);
        assertEq(uint256(vault.rho()), deployTimestamp);
        assertEq(uint256(vault.ssr()), 1e27);

        vm.prank(setter);
        vm.expectEmit(address(vault));
        emit Drip(1e27, 0);
        emit SsrSet(setter, 1e27, FOUR_PCT_SSR);
        vault.setSsr(FOUR_PCT_SSR);

        assertEq(uint256(vault.chi()), 1e27);
        assertEq(uint256(vault.rho()), block.timestamp);
        assertEq(uint256(vault.ssr()), FOUR_PCT_SSR);

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
