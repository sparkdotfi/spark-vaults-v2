// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "../TestBase.t.sol";

contract SparkBoostedVaultVestingCurveTest is SparkBoostedVaultTestBase {

    address user1 = makeAddr("user1");

    /**********************************************************************************************/
    /*** vestingMultiplier Tests                                                                ***/
    /**********************************************************************************************/

    function test_vestingMultiplier_noPosition() external view {
        assertEq(vault.vestingMultiplier(user1), 0);
    }

    function test_vestingMultiplier_beforeCliff() external {
        _deposit(user1, 100_000e6);

        skip(CLIFF - 1);
        assertEq(vault.vestingMultiplier(user1), 0);
    }

    function test_vestingMultiplier_atCliffBoundary() external {
        _deposit(user1, 100_000e6);

        skip(CLIFF - 1);

        assertEq(vault.vestingMultiplier(user1), 0);  // zero just before cliff

        skip(1);

        // (CLIFF^2 / TERM^2) * RAY = (90*86400)^2 * RAY / (365*86400)^2 = 324*RAY/5329
        uint256 expectedAtCliff = uint256(CLIFF) * uint256(CLIFF) * RAY / (uint256(TERM) * uint256(TERM));

        assertEq(vault.vestingMultiplier(user1), expectedAtCliff);
    }

    function test_vestingMultiplier_atTermBoundary() external {
        _deposit(user1, 100_000e6);

        skip(TERM - 1);

        uint256 expectedAtTermBoundary = uint256(TERM - 1) * uint256(TERM - 1) * RAY / (uint256(TERM) * uint256(TERM));

        assertEq(vault.vestingMultiplier(user1), expectedAtTermBoundary);

        skip(1);

        assertEq(vault.vestingMultiplier(user1), RAY);
    }

    function test_vestingMultiplier_afterTerm() external {
        _deposit(user1, 100_000e6);

        skip(TERM + 365 days);

        assertEq(vault.vestingMultiplier(user1), RAY);
    }

    function testFuzz_vestingMultiplier(uint256 elapsed) external {
        elapsed = bound(elapsed, CLIFF, TERM - 1);

        _deposit(user1, 100_000e6);

        skip(elapsed);

        uint256 expected = elapsed * elapsed * RAY / (uint256(TERM) * uint256(TERM));

        assertEq(vault.vestingMultiplier(user1), expected);
    }

    /**********************************************************************************************/
    /*** vestedYieldOf Tests                                                                    ***/
    /**********************************************************************************************/

    function test_vestedYieldOf_noYield() external {
        _deposit(user1, 100_000e6);

        skip(180 days);  // VSR == RAY so chi never changes

        assertEq(vault.vestedYieldOf(user1), 0);
    }

    function test_vestedYieldOf_beforeCliff() external {
        _deposit(user1, 100_000e6);
        _setVsr(FOUR_PCT_VSR);

        skip(CLIFF - 1);

        assertGt(vault.assetsOf(user1),      100_000e6);  // yield accrued but not vested
        assertEq(vault.vestedYieldOf(user1), 0);
    }

    function test_vestedYieldOf_afterCliff() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(180 days);

        uint256 rawYield   = vault.assetsOf(user1) - amount;
        uint256 multiplier = vault.vestingMultiplier(user1);
        uint256 expected   = rawYield * multiplier / RAY;

        assertEq(vault.vestedYieldOf(user1), expected);
    }

    function test_vestedYieldOf_afterTerm() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(TERM);

        uint256 rawYield = vault.assetsOf(user1) - amount;

        assertEq(vault.vestingMultiplier(user1), RAY);
        assertEq(vault.vestedYieldOf(user1),     rawYield);
    }

    /**********************************************************************************************/
    /*** unvestedYieldOf Tests                                                                  ***/
    /**********************************************************************************************/

    function test_unvestedYieldOf_beforeCliff() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(CLIFF - 1);

        uint256 rawYield = vault.assetsOf(user1) - amount;

        assertGt(rawYield,                     0);
        assertEq(vault.unvestedYieldOf(user1), rawYield);  // all yield is unvested before cliff
    }

    function test_unvestedYieldOf_afterCliff() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(180 days);

        uint256 rawYield = vault.assetsOf(user1) - amount;
        uint256 vested   = vault.vestedYieldOf(user1);

        assertEq(vault.unvestedYieldOf(user1), rawYield - vested);
    }

    function test_unvestedYieldOf_afterTerm() external {
        _deposit(user1, 100_000e6);
        _setVsr(FOUR_PCT_VSR);

        skip(TERM);

        assertEq(vault.unvestedYieldOf(user1), 0);  // fully vested at term
    }

    /**********************************************************************************************/
    /*** withdrawableOf Tests                                                                   ***/
    /**********************************************************************************************/

    function test_withdrawableOf_beforeCliff() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(CLIFF - 1);

        assertEq(vault.withdrawableOf(user1), amount);  // Only the principal is withdrawable before cliff
    }

    function test_withdrawableOf_afterCliff() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(180 days);

        uint256 vestedYield = vault.vestedYieldOf(user1);

        assertGt(vestedYield,                 0);
        assertEq(vault.withdrawableOf(user1), amount + vestedYield);
    }

    function test_withdrawableOf_afterTerm() external {
        uint256 amount = 100_000e6;

        _deposit(user1, amount);
        _setVsr(FOUR_PCT_VSR);

        skip(TERM);

        assertEq(vault.withdrawableOf(user1), vault.assetsOf(user1));
    }

    function testFuzz_withdrawableOf(uint256 elapsed) external {
        elapsed = bound(elapsed, 0, 2 * uint256(TERM));

        _deposit(user1, 100_000e6);
        _setVsr(FOUR_PCT_VSR);

        skip(elapsed);

        uint256 rawYield = vault.assetsOf(user1) - vault.principalOf(user1);
        uint256 vested   = vault.vestedYieldOf(user1);
        uint256 unvested = vault.unvestedYieldOf(user1);

        assertEq(vested + unvested, rawYield);
    }

}
