// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./TestBase.t.sol";

uint256 constant ONE_PCT_SSR  = 1.000000000315522921573372069e27;
uint256 constant FOUR_PCT_SSR = 1.000000001243680656318820312e27;
uint256 constant MAX_SSR      = 1.000000021979553151239153027e27;

contract VaultSetSsrBoundsFailureTests is VaultTestBase {

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

contract VaultSetSsrBoundsSuccessTests is VaultUnitTestBase {

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

contract VaultSetSsrFailureTests is VaultUnitTestBase {

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

contract VaultSetSsrSuccessTests is VaultTestBase {

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

contract VaultTakeFailureTests is VaultTestBase {

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

contract VaultTakeSuccessTests is VaultTestBase {

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
