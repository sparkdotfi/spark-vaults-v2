// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "../TestBase.t.sol";

contract SparkBoostedVaultConstructorTests is SparkBoostedVaultTestBase {

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor_invalidTerm() external {
        vm.expectRevert("SparkBoostedVault/invalid-term");
        new SparkBoostedVault(address(asset), "name", "sym", admin, 0, 0);
    }

    function test_constructor_revertsCliffGreaterThanTerm() external {
        vm.expectRevert("SparkBoostedVault/cliff-gt-term");
        new SparkBoostedVault(address(asset), "name", "sym", admin, 365 days, 365 days + 1);
    }

    function test_constructor_cliffEqualsTerm() external {
        SparkBoostedVault v = new SparkBoostedVault(
            address(asset), "n", "s", admin, 365 days, 365 days
        );

        assertEq(v.term(),  365 days);
        assertEq(v.cliff(), 365 days);
    }

    function test_constructor_zeroCliff() external {
        SparkBoostedVault v = new SparkBoostedVault(
            address(asset), "n", "s", admin, 365 days, 0
        );

        assertEq(v.cliff(), 0);
    }

    function test_constructor() external {
        SparkBoostedVault vault_ = new SparkBoostedVault(
            address(asset),
            "Spark Boosted USDC",
            "sbUSDC",
            admin,
            TERM,
            CLIFF
        );

        assertEq(vault_.asset(),          address(asset));
        assertEq(vault_.name(),           "Spark Boosted USDC");
        assertEq(vault_.symbol(),         "sbUSDC");
        assertEq(vault_.version(),        "1");
        assertEq(vault_.decimals(),       6);
        assertEq(vault_.term(),           TERM);
        assertEq(vault_.cliff(),          CLIFF);
        assertEq(vault_.chi(),            uint192(RAY));
        assertEq(vault_.rho(),            uint64(block.timestamp));
        assertEq(vault_.vsr(),            RAY);
        assertEq(vault_.minVsr(),         RAY);
        assertEq(vault_.maxVsr(),         RAY);
        assertEq(vault_.depositCap(),     0);
        assertEq(vault_.totalShares(),    0);
        assertEq(vault_.totalPrincipal(), 0);
        assertEq(vault_.totalAssets(),    0);

        assertEq(vault_.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
        assertEq(vault_.getRoleMember(DEFAULT_ADMIN_ROLE, 0),   admin);
    }

}
