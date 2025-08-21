// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { stdError } from "forge-std/Test.sol";

import "./TestBase.t.sol";

import { SparkVault } from "src/SparkVault.sol";

contract SparkVaultHarness is SparkVault {

    function divup(uint256 x, uint256 y) public pure returns (uint256) {
        return super._divup(x, y);
    }

    function rpow(uint256 x, uint256 n) public pure returns (uint256) {
        return super._rpow(x, n);
    }

}

contract MathTestBase is Test {

    // NOTE: Don't need to use upgradability pattern because of pure functions
    SparkVaultHarness harness;

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

        testCases[0] = TestCase({ x: 1,  y: 1, expected: 1 });  // 1
        testCases[1] = TestCase({ x: 1,  y: 2, expected: 1 });  // 0.5
        testCases[2] = TestCase({ x: 2,  y: 2, expected: 1 });  // 1
        testCases[3] = TestCase({ x: 2,  y: 3, expected: 1 });  // 0.66...
        testCases[4] = TestCase({ x: 3,  y: 2, expected: 2 });  // 1.5
        testCases[5] = TestCase({ x: 5,  y: 2, expected: 3 });  // 2.5
        testCases[6] = TestCase({ x: 10, y: 3, expected: 4 });  // 3.33...

        testCases[7] = TestCase({ x: 1e6, y: 1e6 + 1, expected: 1 });  // 0.999999
        testCases[8] = TestCase({ x: 1e6, y: 1e6,     expected: 1 });  // 1
        testCases[9] = TestCase({ x: 1e6, y: 1e6 - 1, expected: 2 });  // 1.000001
    }

    function table_divup_roundUp(TestCase memory division) public view {
        assertEq(harness.divup(division.x, division.y), division.expected);
    }

}

contract RpowSuccessTests is MathTestBase {

    struct ApySsrTestCase {
        uint256 apy;
        uint256 ssr;
    }

    // NOTE: The CSV data was sourced from Sky Ecosystem's SSR conversion table:
    //       https://ipfs.io/ipfs/QmVp4mhhbwWGTfbh2BzwQB9eiBrQBKiqcPRZCaAxNUaar6
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

    function table_rpow_apySsr18Decimals(ApySsrTestCase memory apySsr) public view {
        uint256 deposit = 1_000_000e18;

        uint256 depositWithYieldApy = deposit * (10000 + apySsr.apy) / 10000;
        uint256 depositWithYieldSsr = deposit * harness.rpow(apySsr.ssr, 365 days) / 1e27;

        assertApproxEqAbs(depositWithYieldApy, depositWithYieldSsr, 150_000);  // 1.5e-13 difference maximum on 1m
    }

    function table_rpow_apySsr6Decimals(ApySsrTestCase memory apySsr) public view {
        uint256 deposit = 1_000_000e6;

        uint256 depositWithYieldApy = deposit * (10000 + apySsr.apy) / 10000;
        uint256 depositWithYieldSsr = deposit * harness.rpow(apySsr.ssr, 365 days) / 1e27;

        assertApproxEqAbs(depositWithYieldApy, depositWithYieldSsr, 1);  // 1 unit of rounding error for 6 decimals
    }

    // Adding this test to demonstrate the upper bound values of rpow instead of failure mode testing.
    // MAX_SSR is 100% APY.
    function test_rpow_upperBoundValues() public {
        uint256 maxSsr = harness.MAX_SSR();

        // Reverts between 75 and 80 years
        vm.expectRevert();
        harness.rpow(maxSsr, 80 * 365 days);

        uint256 maxSsrChi = harness.rpow(maxSsr, 75 * 365 days);

        // 37,778,931,862,957,161,634,615,052,296,000,273,248,252,349,772,281% accrued over 75 years at 100% APY
        // without drip getting called.
        assertEq(maxSsrChi, 3.7778931862957161634615052296000273248252349772281e49);
    }

    function test_rpow_lowerBoundValues() public view {
        uint256 minSsr = 1e27;

        uint256 minSsrChi = harness.rpow(minSsr, 1000 * 365 days);

        assertEq(minSsrChi, 1e27);
    }

}
