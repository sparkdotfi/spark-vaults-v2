// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { TokenFuzzChecks } from "lib/token-tests/src/TokenFuzzChecks.sol";

import "./TestBase.t.sol";

contract ERC20TokenTests is VaultUnitTestBase, TokenFuzzChecks {

    function setUp() public override {
        super.setUp();
        vm.startPrank(admin);
        vault.setSsrBounds(1e27, vault.MAX_SSR());
        vm.stopPrank();
    }

    function testERC20() public {
        checkBulkERC20(address(vault), "Vault", "Spark Savings USDC V2", "spUSDC", "1", 18);
    }

    function testERC20Fuzz(uint256 amount1, uint256 amount2, uint256 ssr, uint256 warpTime) public {
        amount1  = bound(amount1,  0,    1e36);
        amount2  = bound(amount2,  0,    1e36);
        ssr      = bound(ssr,      1e27, 1.000000012857214317438491659e27);  // 0 to 50% APY
        warpTime = bound(warpTime, 0,    10 days);

        vm.prank(setter);
        vault.setSsr(ssr);

        skip(warpTime);

        checkBulkERC20Fuzz({
            _token        : address(vault),
            _contractName : "Vault",
            from          : makeAddr("from"),
            to            : makeAddr("to"),
            amount1       : amount1,
            amount2       : amount2
        });
    }

    function testPermit() public {
        checkBulkPermit(address(vault), "Vault");
    }

    function testPermitFuzz(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        uint128 privateKey
    )
        public
    {
        amount     = bound(amount,   0,               1e36);
        deadline   = bound(deadline, block.timestamp, block.timestamp + 100 days);
        nonce      = bound(nonce,    0,               type(uint256).max);

        checkBulkPermitFuzz({
            _token        : address(vault),
            _contractName : "Vault",
            privKey       : privateKey,
            to            : makeAddr("to"),
            amount        : amount,
            deadline      : deadline,
            nonce         : nonce
        });
    }

}
