// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.35;

import { Test } from "../../lib/forge-std/src/Test.sol";


import { IAccessControlEnumerable } from "../../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";
import { IAccessControl }           from "../../lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { ERC1967Proxy }             from "../../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC165 }                  from "../../lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { EnumerableSet }            from "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import { Initializable } from "../../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import { ISparkBoostedVault } from "../../src/ISparkBoostedVault.sol";
import { SparkBoostedVault }  from "../../src/SparkBoostedVault.sol";

interface IERC20Like {

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

}

contract SparkBoostedVaultHarness is SparkBoostedVault {

    using EnumerableSet for EnumerableSet.UintSet;

    constructor() SparkBoostedVault() {}

    function __setPosition(uint256 positionId, ISparkBoostedVault.Position memory position) external {
        _getVaultStorage().positions[positionId] = position;
    }

    function __addPositionId(address account, uint256 positionId) external {
        _getVaultStorage().positionIdSets[account].add(positionId);
    }

    function __removePositionId(address account, uint256 positionId) external {
        _getVaultStorage().positionIdSets[account].remove(positionId);
    }

    function __setTotalShares(uint256 totalShares_) external {
        _getVaultStorage().totalShares = totalShares_;
    }

    function __setTotalPrincipal(uint256 totalPrincipal_) external {
        _getVaultStorage().totalPrincipal = totalPrincipal_;
    }

    function __setChi(uint192 chi_) external {
        _getVaultStorage().chi = chi_;
    }

    function __setRho(uint64 rho_) external {
        _getVaultStorage().rho = rho_;
    }

    function __setAsset(address asset_) external {
        _getVaultStorage().asset = asset_;
    }

    function __setMaxLiabilityCap(uint256 maxLiabilityCap_) external {
        _getVaultStorage().maxLiabilityCap = maxLiabilityCap_;
    }

    function __setMaxVsr(uint256 maxVsr_) external {
        _getVaultStorage().maxVsr = maxVsr_;
    }

    function __setMinVsr(uint256 minVsr_) external {
        _getVaultStorage().minVsr = minVsr_;
    }

    function __setVsr(uint256 vsr_) external {
        _getVaultStorage().vsr = vsr_;
    }

    function __setCliff(uint64 cliff_) external {
        _getVaultStorage().cliff = cliff_;
    }

    function __setTerm(uint64 term_) external {
        _getVaultStorage().term = term_;
    }

}

contract SparkBoostedVault_UnitTests is Test {

    uint256 internal constant RAY          = 1e27;
    uint256 internal constant ONE_PCT_VSR  = 1.000000000315522921573372069e27;
    uint256 internal constant FOUR_PCT_VSR = 1.000000001243680656318820312e27;
    uint256 internal constant TEN_PCT_VSR  = 1.000000003022265980097387650e27;
    uint256 internal constant MAX_VSR      = 1.000000021979553151239153027e27;

    uint64 internal constant CLIFF = 90 days;
    uint64 internal constant TERM  = 365 days;

    address internal admin  = makeAddr("admin");
    address internal asset  = makeAddr("asset");
    address internal setter = makeAddr("setter");
    address internal taker  = makeAddr("taker");
    address internal user1  = makeAddr("user1");
    address internal user2  = makeAddr("user2");

    bytes32 internal DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 internal TAKER_ROLE         = keccak256("TAKER_ROLE");

    SparkBoostedVaultHarness internal vault;

    function setUp() external {
        vm.warp(1_782_000_000);

        vault = SparkBoostedVaultHarness(
            address(new ERC1967Proxy(
                address(new SparkBoostedVaultHarness()),
                abi.encodeCall(
                    SparkBoostedVault.initialize,
                    (asset, admin, TERM, CLIFF)
                )
            ))
        );

        vm.startPrank(admin);
        vault.grantRole(SETTER_ROLE, setter);
        vault.grantRole(TAKER_ROLE,  taker);
        vm.stopPrank();
    }

    /**********************************************************************************************/
    /*** Initialization Tests                                                                   ***/
    /**********************************************************************************************/

    function test_initialize_disabledOnImplementation() external {
        address implementation = address(new SparkBoostedVault());

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        SparkBoostedVault(implementation).initialize(asset, admin, 0, 0);
    }

    function test_initialize_invalidTerm() external {
        address implementation = address(new SparkBoostedVault());

        vm.expectRevert("SparkBoostedVault/invalid-term");
        new ERC1967Proxy(
            implementation,
            abi.encodeCall(
                SparkBoostedVault.initialize,
                (asset, admin, 0, 0)
            )
        );
    }

    function test_initialize_invalidCliffBoundary() external {
        address implementation = address(new SparkBoostedVault());

        vm.expectRevert("SparkBoostedVault/cliff-gt-term");
        new ERC1967Proxy(
            implementation,
            abi.encodeCall(
                SparkBoostedVault.initialize,
                (asset, admin, 365 days, 365 days + 1)
            )
        );

        new ERC1967Proxy(
            implementation,
            abi.encodeCall(
                SparkBoostedVault.initialize,
                (asset, admin, 365 days, 365 days)
            )
        );
    }

    function test_initialize() external view {
        assertEq(vault.asset(),           asset);
        assertEq(vault.VERSION(),         "1");
        assertEq(vault.term(),            TERM);
        assertEq(vault.cliff(),           CLIFF);
        assertEq(vault.chi(),             uint192(RAY));
        assertEq(vault.rho(),             uint64(block.timestamp));
        assertEq(vault.vsr(),             RAY);
        assertEq(vault.minVsr(),          RAY);
        assertEq(vault.maxVsr(),          RAY);
        assertEq(vault.maxLiabilityCap(), 0);
        assertEq(vault.totalShares(),     0);
        assertEq(vault.totalPrincipal(),  0);
        assertEq(vault.maxLiability(),    0);

        assertEq(vault.getRoleMemberCount(DEFAULT_ADMIN_ROLE), 1);
        assertEq(vault.getRoleMember(DEFAULT_ADMIN_ROLE, 0),   admin);
    }

    /**********************************************************************************************/
    /*** setMaxLiabilityCap Tests                                                               ***/
    /**********************************************************************************************/

    function test_setMaxLiabilityCap_unauthorized() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        vault.setMaxLiabilityCap(1_000_000e6);
    }

    function test_setMaxLiabilityCap() external {
        assertEq(vault.maxLiabilityCap(), 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.MaxLiabilityCapSet(1_000_000e6);

        vm.prank(admin);
        vault.setMaxLiabilityCap(1_000_000e6);

        assertEq(vault.maxLiabilityCap(), 1_000_000e6);
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
        vm.expectRevert("SparkBoostedVault/vsr-too-low");
        vm.prank(admin);
        vault.setVsrBounds(RAY - 1, FOUR_PCT_VSR);

        vm.prank(admin);
        vault.setVsrBounds(RAY, FOUR_PCT_VSR);
    }

    function test_setVsrBounds_vsrTooHighBoundary() external {
        vm.expectRevert("SparkBoostedVault/vsr-too-high");
        vm.prank(admin);
        vault.setVsrBounds(RAY, MAX_VSR + 1);

        vm.prank(admin);
        vault.setVsrBounds(RAY, MAX_VSR);
    }

    function test_setVsrBounds_minGtMaxBoundary() external {
        vm.expectRevert("SparkBoostedVault/min-vsr-gt-max-vsr");
        vm.prank(admin);
        vault.setVsrBounds(FOUR_PCT_VSR + 1, FOUR_PCT_VSR);

        vm.prank(admin);
        vault.setVsrBounds(FOUR_PCT_VSR, FOUR_PCT_VSR);
    }

    function test_setVsrBounds() external {
        assertEq(vault.minVsr(), RAY);
        assertEq(vault.maxVsr(), RAY);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.VsrBoundsSet(FOUR_PCT_VSR, ONE_PCT_VSR);

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

        vm.expectRevert("SparkBoostedVault/vsr-too-low");
        vm.prank(setter);
        vault.setVsr(ONE_PCT_VSR - 1);

        vm.prank(setter);
        vault.setVsr(ONE_PCT_VSR);
    }

    function test_setVsr_tooHighBoundary() external {
        vm.prank(admin);
        vault.setVsrBounds(ONE_PCT_VSR, FOUR_PCT_VSR);

        vm.expectRevert("SparkBoostedVault/vsr-too-high");
        vm.prank(setter);
        vault.setVsr(FOUR_PCT_VSR + 1);

        vm.prank(setter);
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
        emit ISparkBoostedVault.Drip(RAY, 0);
        emit ISparkBoostedVault.VsrSet(setter, FOUR_PCT_VSR);

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
        vm.mockCall(asset, abi.encodeCall(IERC20Like.balanceOf, (address(vault))), abi.encode(uint256(1_000e6)));

        vm.expectRevert("SparkBoostedVault/insufficient-liquidity");
        vm.prank(taker);
        vault.take(1_000e6 + 1);

        vm.mockCall(asset, abi.encodeCall(IERC20Like.balanceOf, (address(vault))), abi.encode(uint256(1_000e6)));

        vm.prank(taker);
        vault.take(1_000e6);
    }

    function test_take() external {
        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(300_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (taker, 300_000e6)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Take(taker, 300_000e6);

        vm.prank(taker);
        vault.take(300_000e6);
    }

    /**********************************************************************************************/
    /*** deposit Tests                                                                          ***/
    /**********************************************************************************************/

    function test_deposit_depositCapExceededBoundary() external {
        vm.prank(admin);
        vault.setMaxLiabilityCap(1_000_000e6);

        vm.expectRevert("SparkBoostedVault/max-liability-cap-exceeded");
        vm.prank(user1);
        vault.deposit(1_000_000e6 + 1);

        vm.mockCall(
            address(asset),
            abi.encodeCall(IERC20Like.transferFrom, (user1, address(vault), 1_000_000e6)),
            abi.encode(true)
        );

        vm.prank(user1);
        vault.deposit(1_000_000e6);
    }

    function test_deposit() external {
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        vm.prank(admin);
        vault.setMaxLiabilityCap(1_000_000e6);

        uint256 amount = 100_000e6;

        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(uint192(RAY), 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Deposit(user1, 1, amount, amount, 0);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transferFrom, (user1, address(vault), amount)),
            abi.encode(true)
        );

        vm.prank(user1);
        uint256 positionId = vault.deposit(amount);

        assertEq(positionId,             1);
        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    amount);
        assertEq(vault.totalPrincipal(), amount);

        ISparkBoostedVault.Position memory position = vault.getPosition(positionId);

        assertEq(position.principal,   amount);
        assertEq(position.shares,      amount);
        assertEq(position.depositTime, uint64(vm.getBlockTimestamp()));

        uint256[] memory positionIds = vault.getPositionIdsOf(user1);

        assertEq(positionIds.length, 1);
        assertEq(positionIds[0],     1);
    }

    function test_deposit_withReferral() external {
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        vm.prank(admin);
        vault.setMaxLiabilityCap(1_000_000e6);

        uint256 amount = 100_000e6;
        uint16  code   = 42;

        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(uint192(RAY), 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Deposit(user1, 1, amount, amount, code);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transferFrom, (user1, address(vault), amount)),
            abi.encode(true)
        );

        vm.prank(user1);
        uint256 positionId = vault.deposit(amount, code);

        assertEq(positionId,             1);
        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    amount);
        assertEq(vault.totalPrincipal(), amount);

        ISparkBoostedVault.Position memory position = vault.getPosition(positionId);

        assertEq(position.principal,   amount);
        assertEq(position.shares,      amount);
        assertEq(position.depositTime, uint64(vm.getBlockTimestamp()));

        uint256[] memory positionIds = vault.getPositionIdsOf(user1);

        assertEq(positionIds.length, 1);
        assertEq(positionIds[0],     1);
    }

    function test_deposit_multipleUsers() external {
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        vm.prank(admin);
        vault.setMaxLiabilityCap(1_000_000e6);

        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(uint192(RAY), 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Deposit(user1, 1, 100_000e6, 100_000e6, 0);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transferFrom, (user1, address(vault), 100_000e6)),
            abi.encode(true)
        );

        vm.prank(user1);
        uint256 positionId1 = vault.deposit(100_000e6);

        assertEq(positionId1,            1);
        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    100_000e6);
        assertEq(vault.totalPrincipal(), 100_000e6);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Deposit(user2, 2, 200_000e6, 200_000e6, 0);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transferFrom, (user2, address(vault), 200_000e6)),
            abi.encode(true)
        );

        vm.prank(user2);
        uint256 positionId2 = vault.deposit(200_000e6);

        assertEq(positionId2,            2);
        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    300_000e6);
        assertEq(vault.totalPrincipal(), 300_000e6);

        ISparkBoostedVault.Position memory position1 = vault.getPosition(positionId1);

        assertEq(position1.principal,   100_000e6);
        assertEq(position1.shares,      100_000e6);
        assertEq(position1.depositTime, uint64(vm.getBlockTimestamp()));

        uint256[] memory user1PositionIds = vault.getPositionIdsOf(user1);

        assertEq(user1PositionIds.length, 1);
        assertEq(user1PositionIds[0],     1);

        ISparkBoostedVault.Position memory position2 = vault.getPosition(positionId2);

        assertEq(position2.principal,   200_000e6);
        assertEq(position2.shares,      200_000e6);
        assertEq(position2.depositTime, uint64(vm.getBlockTimestamp()));

        uint256[] memory user2PositionIds = vault.getPositionIdsOf(user2);

        assertEq(user2PositionIds.length, 1);
        assertEq(user2PositionIds[0],     2);
    }

    /**********************************************************************************************/
    /*** withdraw Tests                                                                         ***/
    /**********************************************************************************************/

    function test_withdraw_zeroPosition() external {
        vm.expectRevert("SparkBoostedVault/zero-position");
        vm.prank(user1);
        vault.withdraw(1);
    }

    function test_withdraw_notOwner() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp())
        }));

        vm.expectRevert("SparkBoostedVault/not-owner");
        vm.prank(user1);
        vault.withdraw(1);
    }

    function test_withdraw_insufficientLiquidity() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - CLIFF + 1)
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);

        vm.mockCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(100_000e6 - 1)
        );

        vm.expectRevert("SparkBoostedVault/insufficient-liquidity");
        vm.prank(user1);
        vault.withdraw(1);

        vm.mockCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(100_000e6)
        );

        vm.prank(user1);
        vault.withdraw(1);
    }

    function test_withdraw_beforeCliff() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - CLIFF + 1)
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 100_000e6)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 100_000e6, 100_000e6);

        vm.prank(user1);
        vault.withdraw(1);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   0);
        assertEq(position.shares,      0);
        assertEq(position.depositTime, 0);
    }

    function test_withdraw_atCliff() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - CLIFF)
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 multiplier  = (uint256(CLIFF) * CLIFF * RAY) / (uint256(TERM) * TERM);
        uint256 yield       = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 vestedYield = (yield * multiplier) / RAY;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 100_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 100_000e6 + vestedYield, 100_000e6);

        vm.prank(user1);
        vault.withdraw(1);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   0);
        assertEq(position.shares,      0);
        assertEq(position.depositTime, 0);
    }

    function test_withdraw_duringVesting() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - (TERM / 2))
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 multiplier  = (uint256(TERM / 2) * (TERM / 2) * RAY) / (uint256(TERM) * TERM);
        uint256 yield       = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 vestedYield = (yield * multiplier) / RAY;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 100_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 100_000e6 + vestedYield, 100_000e6);

        vm.prank(user1);
        vault.withdraw(1);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   0);
        assertEq(position.shares,      0);
        assertEq(position.depositTime, 0);
    }

    function test_withdraw_atTerm() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - TERM)
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 vestedYield = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 100_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 100_000e6 + vestedYield, 100_000e6);

        vm.prank(user1);
        vault.withdraw(1);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   0);
        assertEq(position.shares,      0);
        assertEq(position.depositTime, 0);
    }

    function test_withdraw_afterTerm() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - (2 * TERM))
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 vestedYield = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 100_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 100_000e6 + vestedYield, 100_000e6);

        vm.prank(user1);
        vault.withdraw(1);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    0);
        assertEq(vault.totalPrincipal(), 0);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   0);
        assertEq(position.shares,      0);
        assertEq(position.depositTime, 0);
    }

    /**********************************************************************************************/
    /*** withdraw partial Tests                                                                 ***/
    /**********************************************************************************************/

    function test_withdraw_partial_zeroPosition() external {
        vm.expectRevert("SparkBoostedVault/zero-position");
        vm.prank(user1);
        vault.withdraw(1, 1);
    }

    function test_withdraw_partial_notOwner() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp())
        }));

        vm.expectRevert("SparkBoostedVault/not-owner");
        vm.prank(user1);
        vault.withdraw(1, 50_000e6);
    }

    function test_withdraw_partial_insufficientLiquidity() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - CLIFF + 1)
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);

        vm.mockCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(40_000e6 - 1)
        );

        vm.expectRevert("SparkBoostedVault/insufficient-liquidity");
        vm.prank(user1);
        vault.withdraw(1, 40_000e6);

        vm.mockCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(40_000e6)
        );

        vm.prank(user1);
        vault.withdraw(1, 40_000e6);
    }

    function test_withdraw_partial_beforeCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF + 1);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 40_000e6)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 40_000e6, 40_000e6);

        vm.prank(user1);
        vault.withdraw(1, 40_000e6);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    60_000e6);
        assertEq(vault.totalPrincipal(), 60_000e6);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   60_000e6);
        assertEq(position.shares,      60_000e6);
        assertEq(position.depositTime, depositTime);
    }

    function test_withdraw_partial_atCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 multiplier  = (uint256(CLIFF) * CLIFF * RAY) / (uint256(TERM) * TERM);
        uint256 yield       = ((40_000e6 * 1.1e27) / RAY) - 40_000e6;
        uint256 vestedYield = (yield * multiplier) / RAY;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 40_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 40_000e6 + vestedYield, 40_000e6);

        vm.prank(user1);
        vault.withdraw(1, 40_000e6 + vestedYield);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    60_000e6);
        assertEq(vault.totalPrincipal(), 60_000e6);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   60_000e6);
        assertEq(position.shares,      60_000e6);
        assertEq(position.depositTime, depositTime);
    }

    function test_withdraw_partial_duringVesting() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (TERM / 2));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 multiplier  = (uint256(TERM / 2) * (TERM / 2) * RAY) / (uint256(TERM) * TERM);
        uint256 yield       = ((40_000e6 * 1.1e27) / RAY) - 40_000e6;
        uint256 vestedYield = (yield * multiplier) / RAY;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 40_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 40_000e6 + vestedYield, 40_000e6);

        vm.prank(user1);
        vault.withdraw(1, 40_000e6 + vestedYield);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    60_000e6);
        assertEq(vault.totalPrincipal(), 60_000e6);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   60_000e6);
        assertEq(position.shares,      60_000e6);
        assertEq(position.depositTime, depositTime);
    }

    function test_withdraw_partial_atTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - TERM);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 vestedYield = ((40_000e6 * 1.1e27) / RAY) - 40_000e6;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 40_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 40_000e6 + vestedYield, 40_000e6);

        vm.prank(user1);
        vault.withdraw(1, 40_000e6 + vestedYield);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    60_000e6);
        assertEq(vault.totalPrincipal(), 60_000e6);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   60_000e6);
        assertEq(position.shares,      60_000e6);
        assertEq(position.depositTime, depositTime);
    }

    function test_withdraw_partial_afterTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (2 * TERM));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__addPositionId(user1, 1);
        vault.__setTotalShares(100_000e6);
        vault.__setTotalPrincipal(100_000e6);
        vault.__setChi(1.1e27);
        vault.__setRho(uint64(vm.getBlockTimestamp()) - 1);

        uint256 vestedYield = ((40_000e6 * 1.1e27) / RAY) - 40_000e6;

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(1_000_000e6)
        );

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.transfer, (user1, 40_000e6 + vestedYield)),
            abi.encode(true)
        );

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(1.1e27, 0);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Withdraw(user1, 1, 40_000e6 + vestedYield, 40_000e6);

        vm.prank(user1);
        vault.withdraw(1, 40_000e6 + vestedYield);

        assertEq(vault.rho(),            vm.getBlockTimestamp());
        assertEq(vault.totalShares(),    60_000e6);
        assertEq(vault.totalPrincipal(), 60_000e6);

        ISparkBoostedVault.Position memory position = vault.getPosition(1);

        assertEq(position.principal,   60_000e6);
        assertEq(position.shares,      60_000e6);
        assertEq(position.depositTime, depositTime);
    }

    /**********************************************************************************************/
    /*** vestingMultiplierOf Tests                                                              ***/
    /**********************************************************************************************/

    function test_vestingMultiplierOf_noPosition() external view {
        assertEq(vault.vestingMultiplierOf(1), 0);
    }

    function test_vestingMultiplierOf_beforeCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF + 1);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        assertEq(vault.vestingMultiplierOf(1), 0);
    }

    function test_vestingMultiplierOf_atCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        uint256 expected = (uint256(CLIFF) * CLIFF * RAY) / (uint256(TERM) * TERM);

        assertEq(vault.vestingMultiplierOf(1), expected);
    }

    function test_vestingMultiplierOf_duringVesting() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (TERM / 2));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        uint256 expected = (uint256(TERM / 2) * (TERM / 2) * RAY) / (uint256(TERM) * TERM);

        assertEq(vault.vestingMultiplierOf(1), expected);
    }

    function test_vestingMultiplierOf_atTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - TERM);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        assertEq(vault.vestingMultiplierOf(1), RAY);
    }

    function test_vestingMultiplierOf_afterTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (2 * TERM));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        assertEq(vault.vestingMultiplierOf(1), RAY);
    }

    function testFuzz_vestingMultiplierOf(uint256 elapsed) external {
        elapsed = bound(elapsed, CLIFF, TERM - 1);

        uint64 depositTime = uint64(vm.getBlockTimestamp() - elapsed);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        uint256 expected = (elapsed * elapsed * RAY) / (TERM * TERM);

        assertEq(vault.vestingMultiplierOf(1), expected);
    }

    /**********************************************************************************************/
    /*** yieldOf Tests                                                                          ***/
    /**********************************************************************************************/

    function test_yieldOf_noPosition() external view {
        assertEq(vault.yieldOf(1), 0);
    }

    function test_yieldOf_zeroYield() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp())
        }));

        vault.__setChi(uint192(RAY));

        assertEq(vault.yieldOf(1), 0);
    }

    function test_yieldOf_positiveYield() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp())
        }));

        vault.__setChi(1.1e27);

        assertEq(vault.yieldOf(1), 10_000e6);
    }

    function test_yieldOf_assetsLessThanPrincipal() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 90_000e6,
            depositTime : uint64(vm.getBlockTimestamp())
        }));

        vault.__setChi(uint192(RAY));

        assertEq(vault.yieldOf(1), 0);
    }

    function testFuzz_yieldOf(uint256 shares, uint256 principal, uint192 chi) external {
        shares    = bound(shares, 0, 1e36);
        principal = bound(principal, 0, 1e36);
        chi       = uint192(bound(chi, RAY, 1e36));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : principal,
            shares      : shares,
            depositTime : uint64(vm.getBlockTimestamp())
        }));

        vault.__setChi(chi);

        uint256 assets   = (shares * chi) / RAY;
        uint256 expected = assets > principal ? (assets - principal) : 0;

        assertEq(vault.yieldOf(1), expected);
    }

    /**********************************************************************************************/
    /*** vestedYieldOf Tests                                                                    ***/
    /**********************************************************************************************/

    function test_vestedYieldOf_noPosition() external view {
        assertEq(vault.vestedYieldOf(1), 0);
    }

    function test_vestedYieldOf_beforeCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF + 1);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        assertEq(vault.vestedYieldOf(1), 0);
    }

    function test_vestedYieldOf_atCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield      = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 multiplier = (uint256(CLIFF) * CLIFF * RAY) / (uint256(TERM) * TERM);
        uint256 expected   = (yield * multiplier) / RAY;

        assertEq(vault.vestedYieldOf(1), expected);
    }

    function test_vestedYieldOf_duringVesting() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (TERM / 2));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield      = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 multiplier = (uint256(TERM / 2) * (TERM / 2) * RAY) / (uint256(TERM) * TERM);
        uint256 expected   = (yield * multiplier) / RAY;

        assertEq(vault.vestedYieldOf(1), expected);
    }

    function test_vestedYieldOf_atTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - TERM);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 expected = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;

        assertEq(vault.vestedYieldOf(1), expected);
    }

    function test_vestedYieldOf_afterTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (2 * TERM));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 expected = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;

        assertEq(vault.vestedYieldOf(1), expected);
    }

    function testFuzz_vestedYieldOf(uint256 elapsed, uint256 shares, uint256 principal, uint192 chi) external {
        elapsed   = bound(elapsed, CLIFF, TERM - 1);
        shares    = bound(shares, 0, 1e36);
        principal = bound(principal, 0, 1e36);
        chi       = uint192(bound(chi, RAY, 1e36));

        uint64 depositTime = uint64(vm.getBlockTimestamp() - elapsed);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : principal,
            shares      : shares,
            depositTime : depositTime
        }));

        vault.__setChi(chi);

        uint256 assets     = (shares * chi) / RAY;
        uint256 yield      = assets > principal ? (assets - principal) : 0;
        uint256 multiplier = (elapsed * elapsed * RAY) / (TERM * TERM);
        uint256 expected   = (yield * multiplier) / RAY;

        assertEq(vault.vestedYieldOf(1), expected);
    }

    /**********************************************************************************************/
    /*** unvestedYieldOf Tests                                                                  ***/
    /**********************************************************************************************/

    function test_unvestedYieldOf_noPosition() external view {
        assertEq(vault.unvestedYieldOf(1), 0);
    }

    function test_unvestedYieldOf_beforeCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF + 1);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 expected = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;

        assertEq(vault.unvestedYieldOf(1), expected);
    }

    function test_unvestedYieldOf_atCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield       = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 multiplier  = (uint256(CLIFF) * CLIFF * RAY) / (uint256(TERM) * TERM);
        uint256 vestedYield = (yield * multiplier) / RAY;
        uint256 expected    = yield - vestedYield;

        assertEq(vault.unvestedYieldOf(1), expected);
    }

    function test_unvestedYieldOf_duringVesting() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (TERM / 2));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield       = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 multiplier  = (uint256(TERM / 2) * (TERM / 2) * RAY) / (uint256(TERM) * TERM);
        uint256 vestedYield = (yield * multiplier) / RAY;
        uint256 expected    = yield - vestedYield;

        assertEq(vault.unvestedYieldOf(1), expected);
    }

    function test_unvestedYieldOf_atTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - TERM);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        assertEq(vault.unvestedYieldOf(1), 0);
    }

    function test_unvestedYieldOf_afterTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (2 * TERM));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        assertEq(vault.unvestedYieldOf(1), 0);
    }

    function testFuzz_unvestedYieldOf(uint256 elapsed, uint256 shares, uint256 principal, uint192 chi) external {
        elapsed = bound(elapsed, CLIFF, TERM - 1);
        shares = bound(shares, 0, 1e36);
        principal = bound(principal, 0, 1e36);
        chi = uint192(bound(chi, RAY, 1e36));

        uint64 depositTime = uint64(vm.getBlockTimestamp() - elapsed);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : principal,
            shares      : shares,
            depositTime : depositTime
        }));

        vault.__setChi(chi);

        uint256 assets      = (shares * chi) / RAY;
        uint256 yield       = assets > principal ? (assets - principal) : 0;
        uint256 multiplier  = (elapsed * elapsed * RAY) / (TERM * TERM);
        uint256 vestedYield = (yield * multiplier) / RAY;
        uint256 expected    = yield - vestedYield;

        assertEq(vault.unvestedYieldOf(1), expected);
    }

    /**********************************************************************************************/
    /*** drip Tests                                                                             ***/
    /**********************************************************************************************/

    function test_drip_rhoIsCurrentTimestamp() external {
        uint64 timestamp = uint64(vm.getBlockTimestamp());

        vault.__setRho(timestamp);
        vault.__setChi(1.1e27);

        vault.drip();

        assertEq(vault.chi(), 1.1e27);
        assertEq(vault.rho(), timestamp);
    }

    function test_drip_rhoInPast_nonZeroShares() external {
        uint64 pastTimestamp = uint64(vm.getBlockTimestamp() - 365 days);

        vault.__setRho(pastTimestamp);
        vault.__setChi(uint192(RAY));
        vault.__setVsr(FOUR_PCT_VSR);
        vault.__setTotalShares(100_000e6);

        uint256 expectedNewChi = 1.039999999999999999955174055e27;
        uint256 expectedDiff = ((100_000e6 * expectedNewChi) / RAY) - 100_000e6;

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(expectedNewChi, expectedDiff);

        vault.drip();

        assertEq(vault.chi(), expectedNewChi);
        assertEq(vault.rho(), vm.getBlockTimestamp());
    }

    function testFuzz_drip(uint256 elapsed, uint256 shares, uint192 chi, uint256 vsr) external {
        elapsed = bound(elapsed, 1, 365 days);
        shares  = bound(shares, 0, 1e36);
        chi     = uint192(bound(chi, RAY, 1e36));
        vsr     = bound(vsr, RAY, FOUR_PCT_VSR);

        uint64 pastTimestamp = uint64(vm.getBlockTimestamp() - elapsed);

        vault.__setRho(pastTimestamp);
        vault.__setChi(chi);
        vault.__setVsr(vsr);
        vault.__setTotalShares(shares);

        uint256 expectedNewChi = (vault.nowChi());
        uint256 expectedDiff = ((shares * expectedNewChi) / RAY) - ((shares * chi) / RAY);

        vm.expectEmit(address(vault));
        emit ISparkBoostedVault.Drip(expectedNewChi, expectedDiff);

        vault.drip();

        assertEq(vault.chi(), expectedNewChi);
        assertEq(vault.rho(), vm.getBlockTimestamp());
    }

    /**********************************************************************************************/
    /*** Getter Tests                                                                           ***/
    /**********************************************************************************************/

    function test_getter_asset() external {
        assertEq(vault.asset(), asset);
        address expected = makeAddr("mockAsset");
        vault.__setAsset(expected);
        assertEq(vault.asset(), expected);
    }

    function test_getter_chi() external {
        assertEq(vault.chi(), uint192(RAY));

        vault.__setChi(1.25e27);

        assertEq(vault.chi(), 1.25e27);
    }

    function test_getter_cliff() external {
        assertEq(vault.cliff(), CLIFF);

        vault.__setCliff(30 days);

        assertEq(vault.cliff(), 30 days);
    }

    function test_getter_maxDeposit() external {
        assertEq(vault.maxDeposit(), 0);

        vault.__setMaxLiabilityCap(500_000e6);
        vault.__setTotalShares(100_000e6);
        vault.__setChi(uint192(RAY));

        assertEq(vault.maxDeposit(), 400_000e6);

        vault.__setMaxLiabilityCap(100_000e6);

        assertEq(vault.maxDeposit(), 0);
    }

    function test_getter_maxLiability() external {
        assertEq(vault.maxLiability(), 0);

        vault.__setTotalShares(100_000e6);
        vault.__setChi(1.15e27);

        assertEq(vault.maxLiability(), 115_000e6);
    }

    function test_getter_maxLiabilityCap() external {
        assertEq(vault.maxLiabilityCap(), 0);

        vault.__setMaxLiabilityCap(1_000_000e6);

        assertEq(vault.maxLiabilityCap(), 1_000_000e6);
    }

    function test_getter_maxVsr() external {
        assertEq(vault.maxVsr(), RAY);

        vault.__setMaxVsr(.05e27);

        assertEq(vault.maxVsr(), .05e27);
    }

    function test_getter_minVsr() external {
        assertEq(vault.minVsr(), RAY);

        vault.__setMinVsr(1.01e27);

        assertEq(vault.minVsr(), 1.01e27);
    }

    function test_getter_nowChi() external {
        assertEq(vault.nowChi(), RAY);

        vault.__setChi(uint192(1.1e27));

        assertEq(vault.nowChi(), 1.1e27);

        vault.__setRho(uint64(vm.getBlockTimestamp() - 365 days));

        assertEq(vault.nowChi(), 1.1e27);

        vault.__setVsr(FOUR_PCT_VSR);

        assertEq(vault.nowChi(), 1.143999999999999999950691460e27);
    }

    function test_getter_rho() external {
        assertEq(vault.rho(), uint64(vm.getBlockTimestamp()));

        vault.__setRho(1_234_567_890);

        assertEq(vault.rho(), 1_234_567_890);
    }

    function test_getter_term() external {
        assertEq(vault.term(), TERM);

        vault.__setTerm(180 days);

        assertEq(vault.term(), 180 days);
    }

    function test_getter_totalPrincipal() external {
        assertEq(vault.totalPrincipal(), 0);

        vault.__setTotalPrincipal(250_000e6);

        assertEq(vault.totalPrincipal(), 250_000e6);
    }

    function test_getter_totalShares() external {
        assertEq(vault.totalShares(), 0);

        vault.__setTotalShares(350_000e6);

        assertEq(vault.totalShares(), 350_000e6);
    }

    function test_getter_vsr() external {
        assertEq(vault.vsr(), RAY);

        vault.__setVsr(1.03e27);

        assertEq(vault.vsr(), 1.03e27);
    }

    /**********************************************************************************************/
    /*** getPosition Tests                                                                      ***/
    /**********************************************************************************************/

    function test_getPosition_nonExistent() external view {
        ISparkBoostedVault.Position memory position = vault.getPosition(999);

        assertEq(position.principal,   0);
        assertEq(position.shares,      0);
        assertEq(position.depositTime, 0);
    }

    function test_getPosition() external {
        ISparkBoostedVault.Position memory expected = ISparkBoostedVault.Position({
            principal   : 123_456e6,
            shares      : 789_012e6,
            depositTime : 1_000_000
        });

        vault.__setPosition(42, expected);

        ISparkBoostedVault.Position memory actual = vault.getPosition(42);

        assertEq(actual.principal,   expected.principal);
        assertEq(actual.shares,      expected.shares);
        assertEq(actual.depositTime, expected.depositTime);
    }

    /**********************************************************************************************/
    /*** getPositionIdsOf Tests                                                                 ***/
    /**********************************************************************************************/

    function test_getPositionIdsOf() external {
        uint256[] memory ids = vault.getPositionIdsOf(user1);

        assertEq(ids.length, 0);

        vault.__addPositionId(user1, 10);

        ids = vault.getPositionIdsOf(user1);

        ids = vault.getPositionIdsOf(user1);

        assertEq(ids.length, 1);
        assertEq(ids[0], 10);

        vault.__addPositionId(user1, 20);

        ids = vault.getPositionIdsOf(user1);

        assertEq(ids.length, 2);
        assertEq(ids[0], 10);
        assertEq(ids[1], 20);

        vault.__addPositionId(user1, 30);

        ids = vault.getPositionIdsOf(user1);

        assertEq(ids.length, 3);
        assertEq(ids[0], 10);
        assertEq(ids[1], 20);
        assertEq(ids[2], 30);

        vault.__removePositionId(user1, 20);

        ids = vault.getPositionIdsOf(user1);

        assertEq(ids.length, 2);
        assertEq(ids[0], 10);
        assertEq(ids[1], 30);
    }

    /**********************************************************************************************/
    /*** getPositionsOf Tests                                                                   ***/
    /**********************************************************************************************/

    function test_getPositionsOf() external {
        ISparkBoostedVault.Position[] memory positions = vault.getPositionsOf(user1);

        assertEq(positions.length, 0);

        ISparkBoostedVault.Position memory position1 = ISparkBoostedVault.Position({
            principal   : 10_000e6,
            shares      : 10_000e6,
            depositTime : 1_000_000
        });

        ISparkBoostedVault.Position memory position2 = ISparkBoostedVault.Position({
            principal   : 20_000e6,
            shares      : 20_000e6,
            depositTime : 2_000_000
        });

        ISparkBoostedVault.Position memory position3 = ISparkBoostedVault.Position({
            principal   : 30_000e6,
            shares      : 30_000e6,
            depositTime : 3_000_000
        });

        vault.__setPosition(10, position1);
        vault.__addPositionId(user1, 10);

        positions = vault.getPositionsOf(user1);

        assertEq(positions.length, 1);

        assertEq(positions[0].principal,   position1.principal);
        assertEq(positions[0].shares,      position1.shares);
        assertEq(positions[0].depositTime, position1.depositTime);

        vault.__setPosition(20, position2);
        vault.__addPositionId(user1, 20);

        positions = vault.getPositionsOf(user1);

        assertEq(positions.length, 2);

        assertEq(positions[0].principal,   position1.principal);
        assertEq(positions[0].shares,      position1.shares);
        assertEq(positions[0].depositTime, position1.depositTime);

        assertEq(positions[1].principal,   position2.principal);
        assertEq(positions[1].shares,      position2.shares);
        assertEq(positions[1].depositTime, position2.depositTime);

        vault.__setPosition(30, position3);
        vault.__addPositionId(user1, 30);

        positions = vault.getPositionsOf(user1);

        assertEq(positions.length, 3);

        assertEq(positions[0].principal,   position1.principal);
        assertEq(positions[0].shares,      position1.shares);
        assertEq(positions[0].depositTime, position1.depositTime);

        assertEq(positions[1].principal,   position2.principal);
        assertEq(positions[1].shares,      position2.shares);
        assertEq(positions[1].depositTime, position2.depositTime);

        assertEq(positions[2].principal,   position3.principal);
        assertEq(positions[2].shares,      position3.shares);
        assertEq(positions[2].depositTime, position3.depositTime);

        vault.__removePositionId(user1, 20);

        positions = vault.getPositionsOf(user1);

        assertEq(positions.length, 2);

        assertEq(positions[0].principal,   position1.principal);
        assertEq(positions[0].shares,      position1.shares);
        assertEq(positions[0].depositTime, position1.depositTime);

        assertEq(positions[1].principal,   position3.principal);
        assertEq(positions[1].shares,      position3.shares);
        assertEq(positions[1].depositTime, position3.depositTime);
    }

    /**********************************************************************************************/
    /*** maxWithdrawOf Tests                                                                    ***/
    /**********************************************************************************************/

    function test_maxWithdrawOf_xxx() external {
        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : uint64(vm.getBlockTimestamp() - TERM)
        }));

        vault.__setChi(1.1e27);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(110_000e6 + 1)
        );

        assertEq(vault.maxWithdrawOf(1), 110_000e6);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(110_000e6)
        );

        assertEq(vault.maxWithdrawOf(1), 110_000e6);

        _mockAndExpectCall(
            address(asset),
            abi.encodeCall(IERC20Like.balanceOf, (address(vault))),
            abi.encode(110_000e6 - 1)
        );

        assertEq(vault.maxWithdrawOf(1), 110_000e6 - 1);
    }

    /**********************************************************************************************/
    /*** withdrawableOf Tests                                                                   ***/
    /**********************************************************************************************/

    function test_withdrawableOf_noPosition() external view {
        assertEq(vault.withdrawableOf(1), 0);
    }

    function test_withdrawableOf_beforeCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF + 1);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        assertEq(vault.withdrawableOf(1), 100_000e6);
    }

    function test_withdrawableOf_atCliff() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - CLIFF);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield       = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 multiplier  = (uint256(CLIFF) * CLIFF * RAY) / (uint256(TERM) * TERM);
        uint256 vestedYield = (yield * multiplier) / RAY;
        uint256 expected    = 100_000e6 + vestedYield;

        assertEq(vault.withdrawableOf(1), expected);
    }

    function test_withdrawableOf_duringVesting() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (TERM / 2));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield       = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 multiplier  = (uint256(TERM / 2) * (TERM / 2) * RAY) / (uint256(TERM) * TERM);
        uint256 vestedYield = (yield * multiplier) / RAY;
        uint256 expected    = 100_000e6 + vestedYield;

        assertEq(vault.withdrawableOf(1), expected);
    }

    function test_withdrawableOf_atTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - TERM);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield    = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 expected = 100_000e6 + yield;

        assertEq(vault.withdrawableOf(1), expected);
    }

    function test_withdrawableOf_afterTerm() external {
        uint64 depositTime = uint64(vm.getBlockTimestamp() - (2 * TERM));

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : 100_000e6,
            shares      : 100_000e6,
            depositTime : depositTime
        }));

        vault.__setChi(1.1e27);

        uint256 yield    = ((100_000e6 * 1.1e27) / RAY) - 100_000e6;
        uint256 expected = 100_000e6 + yield;

        assertEq(vault.withdrawableOf(1), expected);
    }

    function testFuzz_withdrawableOf(uint256 elapsed, uint256 shares, uint256 principal, uint192 chi) external {
        elapsed   = bound(elapsed, CLIFF, TERM - 1);
        shares    = bound(shares, 0, 1e36);
        principal = bound(principal, 0, 1e36);
        chi       = uint192(bound(chi, RAY, 1e36));

        uint64 depositTime = uint64(vm.getBlockTimestamp() - elapsed);

        vault.__setPosition(1, ISparkBoostedVault.Position({
            principal   : principal,
            shares      : shares,
            depositTime : depositTime
        }));

        vault.__setChi(chi);

        uint256 assets      = (shares * chi) / RAY;
        uint256 yield       = assets > principal ? (assets - principal) : 0;
        uint256 multiplier  = (elapsed * elapsed * RAY) / (TERM * TERM);
        uint256 vestedYield = (yield * multiplier) / RAY;
        uint256 expected    = principal + vestedYield;

        assertEq(vault.withdrawableOf(1), expected);
    }

    /**********************************************************************************************/
    /*** supportsInterface Tests                                                                ***/
    /**********************************************************************************************/

    function test_supportsInterface() external view {
        assertTrue(vault.supportsInterface(type(ISparkBoostedVault).interfaceId));
        assertTrue(vault.supportsInterface(type(IAccessControlEnumerable).interfaceId));
        assertTrue(vault.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(vault.supportsInterface(type(IERC165).interfaceId));

        assertFalse(vault.supportsInterface(0xffffffff));
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _mockAndExpectCall(address callee, bytes memory data, bytes memory returnData) internal {
        vm.expectCall(callee, data);
        vm.mockCall(callee, data, returnData);
    }

}
