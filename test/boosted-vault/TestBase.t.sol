// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

import { ERC20Mock } from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { SparkBoostedVault } from "../../src/SparkBoostedVault.sol";

contract MockERC20 is ERC20Mock {

    function decimals() public pure override returns (uint8) {
        return 6; 
    }

}

contract SparkBoostedVaultTestBase is Test {

    uint256 constant RAY          = 1e27;
    uint256 constant ONE_PCT_VSR  = 1.000000000315522921573372069e27;
    uint256 constant FOUR_PCT_VSR = 1.000000001243680656318820312e27;
    uint256 constant TEN_PCT_VSR  = 1.000000003022265980097387650e27;
    uint256 constant MAX_VSR      = 1.000000021979553151239153027e27;

    uint64 constant TERM  = 365 days;
    uint64 constant CLIFF = 90 days;

    address admin  = makeAddr("admin");
    address setter = makeAddr("setter");
    address taker  = makeAddr("taker");

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 TAKER_ROLE         = keccak256("TAKER_ROLE");

    MockERC20         asset;
    SparkBoostedVault vault;

    function setUp() public virtual {
        asset = new MockERC20();

        vault = new SparkBoostedVault(
            address(asset),
            "Spark Boosted USDC",
            "sbUSDC",
            admin,
            TERM,
            CLIFF
        );

        vm.startPrank(admin);
    
        vault.grantRole(SETTER_ROLE, setter);
    
        vault.grantRole(TAKER_ROLE,  taker);
    
        vault.setDepositCap(1_000_000e6);

        vm.stopPrank();
    }

    // Deposit assets into the vault.
    function _deposit(address user, uint256 amount) internal {
        deal(address(asset), user, amount);

        vm.startPrank(user);

        asset.approve(address(vault), amount);

        vault.deposit(amount);

        vm.stopPrank();
    }

    // Enable yield: open VSR bounds to [RAY, vsrValue] and set VSR.
    function _setVsr(uint256 maxVsr) internal {
        vm.prank(admin);
        vault.setVsrBounds(RAY, maxVsr);
        
        vm.prank(setter);
        vault.setVsr(maxVsr);
    }

    // Deal the vault's asset balance up to its current totalAssets() so withdrawals succeed.
    function _fundVaultToTotalAssets() internal {
        deal(address(asset), address(vault), vault.totalAssets());
    }

}
