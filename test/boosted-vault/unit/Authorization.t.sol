// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "../TestBase.t.sol";

contract SparkBoostedVaultAuthorizationTests is SparkBoostedVaultTestBase {

    event DepositCapSet(uint256 oldCap, uint256 newCap);
    event VsrBoundsSet(uint256 oldMinVsr, uint256 oldMaxVsr, uint256 newMinVsr, uint256 newMaxVsr);
    event VsrSet(address indexed sender, uint256 oldVsr, uint256 newVsr);
    event Drip(uint256 chi, uint256 diff);
    event Take(address indexed to, uint256 value);

    /**********************************************************************************************/
    /*** setDepositCap Tests                                                                    ***/
    /**********************************************************************************************/

    function test_setDepositCap_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        vault.setDepositCap(2_000_000e6);
    }

    function test_setDepositCap() external {
        assertEq(vault.depositCap(), 1_000_000e6);

        vm.expectEmit(address(vault));
        emit DepositCapSet(1_000_000e6, 2_000_000e6);
        vm.prank(admin);
        vault.setDepositCap(2_000_000e6);

        assertEq(vault.depositCap(), 2_000_000e6);
    }

    /**********************************************************************************************/
    /*** setVsrBounds Tests                                                                     ***/
    /**********************************************************************************************/

    function test_setVsrBounds_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        vault.setVsrBounds(RAY, FOUR_PCT_VSR);
    }

    function test_setVsrBounds_vsrTooLowBoundary() external {
        vm.startPrank(admin);
        vm.expectRevert("SparkBoostedVault/vsr-too-low");
        vault.setVsrBounds(RAY - 1, FOUR_PCT_VSR);

        vault.setVsrBounds(RAY, FOUR_PCT_VSR);
    }

    function test_setVsrBounds_vsrTooHighBoundary() external {
        vm.startPrank(admin);
        vm.expectRevert("SparkBoostedVault/vsr-too-high");
        vault.setVsrBounds(RAY, MAX_VSR + 1);

        vault.setVsrBounds(RAY, MAX_VSR);
    }

    function test_setVsrBounds_minGtMaxBoundary() external {
        vm.startPrank(admin);
        vm.expectRevert("SparkBoostedVault/min-vsr-gt-max-vsr");
        vault.setVsrBounds(FOUR_PCT_VSR + 1, FOUR_PCT_VSR);

        vault.setVsrBounds(FOUR_PCT_VSR, FOUR_PCT_VSR);
    }

    function test_setVsrBounds() external {
        assertEq(vault.minVsr(), RAY);
        assertEq(vault.maxVsr(), RAY);

        vm.expectEmit(address(vault));
        emit VsrBoundsSet(RAY, RAY, ONE_PCT_VSR, FOUR_PCT_VSR);
        vm.prank(admin);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        assertEq(vault.minVsr(), ONE_PCT_VSR);
        assertEq(vault.maxVsr(), FOUR_PCT_VSR);
    }

    /**********************************************************************************************/
    /*** setVsr Tests                                                                           ***/
    /**********************************************************************************************/

    function test_setVsr_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            SETTER_ROLE
        ));
        vault.setVsr(RAY);
    }

    function test_setVsr_tooLowBoundary() external {
        vm.prank(admin);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        vm.startPrank(setter);
        vm.expectRevert("SparkBoostedVault/vsr-too-low");
        vault.setVsr(ONE_PCT_VSR - 1);

        vault.setVsr(ONE_PCT_VSR);
    }

    function test_setVsr_tooHighBoundary() external {
        vm.prank(admin);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        vm.startPrank(setter);
        vm.expectRevert("SparkBoostedVault/vsr-too-high");
        vault.setVsr(FOUR_PCT_VSR + 1);

        vault.setVsr(FOUR_PCT_VSR);
    }

    function test_setVsr() external {
        vm.prank(admin);
        vault.setVsrBounds(RAY, FOUR_PCT_VSR);

        uint256 deployTimestamp = block.timestamp;
        skip(10 days);

        assertEq(vault.chi(), uint192(RAY));
        assertEq(vault.rho(), uint64(deployTimestamp));
        assertEq(vault.vsr(), RAY);

        vm.expectEmit(address(vault));
        emit Drip(RAY, 0);
        emit VsrSet(setter, RAY, FOUR_PCT_VSR);
        vm.prank(setter);
        vault.setVsr(FOUR_PCT_VSR);

        assertEq(vault.chi(), uint192(RAY));
        assertEq(vault.rho(), uint64(block.timestamp));
        assertEq(vault.vsr(), FOUR_PCT_VSR);

        skip(365 days);
        assertGt(vault.nowChi(), RAY);
    }

    /**********************************************************************************************/
    /*** take Tests                                                                             ***/
    /**********************************************************************************************/

    function test_take_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            TAKER_ROLE
        ));
        vault.take(1_000e6);
    }

    function test_take_insufficientLiquidityBoundary() external {
        deal(address(asset), address(vault), 1_000e6);

        vm.startPrank(taker);
        vm.expectRevert("SparkBoostedVault/insufficient-liquidity");
        vault.take(1_000e6 + 1);

        vault.take(1_000e6);
    }

    function test_take() external {
        deal(address(asset), address(vault), 500_000e6);

        assertEq(asset.balanceOf(address(vault)), 500_000e6);
        assertEq(asset.balanceOf(taker),          0);

        vm.expectEmit(address(vault));
        emit Take(taker, 500_000e6);
        vm.prank(taker);
        vault.take(500_000e6);

        assertEq(asset.balanceOf(address(vault)), 0);
        assertEq(asset.balanceOf(taker),          500_000e6);
    }

}
