// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { SparkVaultInvariantTestBase } from "./InvariantsBase.t.sol";

import { AdminHandler }    from "./handlers/AdminHandler.sol";
import { ExternalHandler } from "./handlers/ExternalHandler.sol";
import { UserHandler }     from "./handlers/UserHandler.sol";

contract SparkVaultInvariantTest is SparkVaultInvariantTestBase {

    function setUp() public override {
        super.setUp();

        // For the purposes of these tests, set unlimited deposit cap
        vm.prank(admin);
        vault.setDepositCap(type(uint256).max);

        adminHandler    = new AdminHandler(address(vault));
        externalHandler = new ExternalHandler(address(vault));
        userHandler     = new UserHandler(address(vault), 5);

        // Foundry will call only the functions of the target contracts
        targetContract(address(adminHandler));
        targetContract(address(externalHandler));
        targetContract(address(userHandler));
    }

    function invariant_userInvariants() public {
        for (uint256 i = 0; i < userHandler.N(); i++) {
            address user = userHandler.users(i);
            _userInvariant_balanceOfCannotChange(user);
            _userInvariant_assetsOfCannotDecrease(user);
            // _userInvariant_userCannotDepositMoreThanMax(user);
            // _userInvariant_userCannotMintMoreThanMax(user);
            // _userInvariant_userCannotRedeemMoreThanMax(user);
            // _userInvariant_userCannotWithdrawMoreThanMax(user);
            _userInvariant_userCanDepositAndWithdrawAtomically(user);
        }
    }
}