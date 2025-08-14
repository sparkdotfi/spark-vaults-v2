// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./TestBase.t.sol";

contract VaultSetSsrFailureTests is VaultUnitTestBase {

    uint256 private constant MAX_SSR = 1.000000021979553151239153027e27;

    function test_setSsr_notSetter() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            SETTER_ROLE
        ));
        vault.setSsr(100);
    }

    function test_setSsr_belowRayBoundary() public {
        vm.startPrank(setter);
        vm.expectRevert("Vault/ssr-too-low");
        vault.setSsr(1e27 - 1);

        vault.setSsr(1e27);
    }

    function test_setSsr_aboveRayBoundary() public {
        vm.startPrank(setter);
        vm.expectRevert("Vault/ssr-too-high");
        vault.setSsr(MAX_SSR + 1);

        vault.setSsr(MAX_SSR);
    }
}

contract VaultSetSsrSuccessTests is VaultUnitTestBase {

    event SsrSet(address sender, uint256 oldSsr, uint256 newSsr);
    event Drip(uint256 nChi, uint256 diff);

    function test_setSsr() public {
        uint256 deployTimestamp = block.timestamp;

        uint256 newSsr = 1.000000001e27;

        skip(10 days);

        assertEq(uint256(vault.chi()), 1e27);
        assertEq(uint256(vault.rho()), deployTimestamp);
        assertEq(uint256(vault.ssr()), 1e27);

        vm.prank(setter);
        vm.expectEmit(address(vault));
        emit Drip(1e27, 0);
        emit SsrSet(setter, 1e27, newSsr);
        vault.setSsr(newSsr);

        assertEq(uint256(vault.chi()), 1e27);
        assertEq(uint256(vault.rho()), block.timestamp);
        assertEq(uint256(vault.ssr()), newSsr);

        assertEq(vault.nowChi(), 1e27);

        skip(10 days);

        assertGt(vault.nowChi(), 1e27);
    }

}

contract VaultTakeFailureTests is VaultUnitTestBase {

    function test_take_notTaker() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            TAKER_ROLE
        ));
        vault.take(1_000_000e6);
    }

    function test_take_insufficientBalanceBoundary() public {
        deal(address(usdc), address(vault), 1_000_000e6);

        vm.startPrank(taker);
        vm.expectRevert();
        vault.take(1_000_000e6 + 1);

        vault.take(1_000_000e6);
    }

}

contract VaultTakeSuccessTests is VaultUnitTestBase {

    function test_take() public {
        deal(address(usdc), address(vault), 1_000_000e6);

        assertEq(usdc.balanceOf(address(vault)), 1_000_000e6);
        assertEq(usdc.balanceOf(taker),          0);

        vm.prank(taker);
        vault.take(1_000_000e6);

        assertEq(usdc.balanceOf(address(vault)), 0);
        assertEq(usdc.balanceOf(taker),          1_000_000e6);
    }

}
