// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { stdError } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import "./TestBase.t.sol";

import { SparkVault } from "../src/SparkVault.sol";

contract SparkVaultHarness is SparkVault {

    function divup(uint256 x, uint256 y) public pure returns (uint256 z) {
        return super._divup(x, y);
    }

    function rpow(uint256 x, uint256 n) public pure returns (uint256 z) {
        return super._rpow(x, n);
    }

}

contract MathTestBase is Test {

    SparkVaultHarness harness;  // NOTE: Don't need to use upgradablility pattern because of pure functions

    uint256 constant RAY = 1e27;

    function setUp() public {
        harness = new SparkVaultHarness();
    }

}

contract DivupFailureTests is MathTestBase {

    function test_divup_divideByZero() public {
        vm.expectRevert(stdError.divisionError);
        harness.divup(1, 0);
    }

}

contract DivupSuccessTests is MathTestBase {

    struct TestCase {
        uint256 x;
        uint256 y;
        uint256 expected;
    }

    function fixtureDivision() public pure returns (TestCase[] memory testCases) {
        testCases = new TestCase[](10);

        testCases[0] = TestCase({ x: 1,  y: 1, expected: 1 });
        testCases[1] = TestCase({ x: 1,  y: 2, expected: 1 });
        testCases[2] = TestCase({ x: 2,  y: 2, expected: 1 });
        testCases[3] = TestCase({ x: 2,  y: 3, expected: 1 });
        testCases[4] = TestCase({ x: 3,  y: 2, expected: 2 });
        testCases[5] = TestCase({ x: 5,  y: 2, expected: 3 });
        testCases[6] = TestCase({ x: 10, y: 3, expected: 4 });

        testCases[7] = TestCase({ x: 1_000_000e6 * RAY, y: RAY + 1, expected: 1_000_000e6 });

        testCases[8] = TestCase({ x: 1_000_000e6 * 1.05e27, y: RAY, expected: 1_000_000e6 });

        testCases[9] = TestCase({ x: 1_000_000e6 * RAY, y: RAY - 1, expected: 1_000_000e6 });

    }

    function table_divup_roundUp(TestCase memory division) public view {
        assertEq(harness.divup(division.x, division.y), division.expected);
    }

}

contract RPowFailureTests is MathTestBase {

    function test_rpow_revertsOnOverflowOnSquareBoundary() public {
        uint256 x = type(uint128).max;  // Any x >= 2^128 will overflow on x*x.
        uint256 n = 2;                      // The loop starts with n := n/2, so use n=2 to ensure at least one iteration.

        vm.expectRevert();
        harness.rpow(x, n);

        harness.rpow(x - 1, n);
    }

    function test_Revert_onZxMulOverflow() public {
        uint256 xWillRevert = 10**35; // big, but x*x fits; z*x overflows in first iter when n=3
        uint256 xSafe       = 10**34; // one order smaller -> no overflow in zx

        uint256 n = 3; // odd -> sets z := x before loop; loop starts with n=1

        vm.expectRevert();                // matches revert(0,0)
        harness.rpow(xWillRevert, n);     // hits: if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }

        // Control: should not revert
        uint256 out = harness.rpow(xSafe, n);
        assertGt(out, 0);
    }

}


contract RpowSuccessTests is MathTestBase {

    function test_rpow_baseRay_evenExponent() public view {
        // Covers: x != 0 branch, even n path (z := RAY), loop executes, all guards true -> no revert
        // Also exercises the eq(div(xx,x),x) check on a sane value.
        uint256 result = harness.rpow(RAY, 2);
        assertEq(result, RAY, "RAY^2 (ray-scaled) should be RAY");
    }

    function test_rpow_baseRay_oddExponent() public view {
        // Covers: odd n path (z := x), and the inner if mod(n,2) branch.
        uint256 result = harness.rpow(RAY, 3);
        assertEq(result, RAY, "RAY^3 (ray-scaled) should be RAY");
    }

    function test_rpow_baseZero_zeroExponent() public view {
        // Covers: x == 0 and n == 0 -> z := RAY
        uint256 result = harness.rpow(0, 0);
        assertEq(result, RAY);
    }

    function test_rpow_zeroBase_positiveExp() public view {
        // Covers: x == 0 and n > 0 -> z := 0
        uint256 result = harness.rpow(0, 5);
        assertEq(result, 0);
    }

    struct ApySsrTestCase {
        uint256 apy;
        uint256 ssr;
    }

    function fixtureApySsr() public view returns (ApySsrTestCase[] memory testCases) {
        string memory csv = vm.readFile("test/tables/rpow-apy.csv");
        string[] memory rows = vm.split(csv, "\n");
        testCases = new ApySsrTestCase[](rows.length);
        for (uint256 i = 0; i < rows.length; i++) {
            testCases[i] = ApySsrTestCase({
                apy: vm.parseUint(vm.split(rows[i], ",")[0]),
                ssr: vm.parseUint(vm.split(rows[i], ",")[1])
            });
        }
    }

    function table_rpow_apySsr(ApySsrTestCase memory apySsr) public view {
        uint256 deposit = 1_000_000e18;

        uint256 depositWithYieldApy = deposit * (10000 + apySsr.apy) / 10000;
        uint256 depositWithYieldSsr = deposit * harness.rpow(apySsr.ssr, 365 days) / 1e27;

        assertApproxEqAbs(depositWithYieldApy, depositWithYieldSsr, 150000);  // 1.5e-13 difference maximum on 1m
    }

}
