// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { StdUtils, StdCheats, Vm, Test, console2 as console, stdError } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { ERC20Mock as MockERC20 } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import { SparkVault } from "src/SparkVault.sol";

contract Init is Test {
    uint256 constant RAY = 10 ** 27;

    // Common storage
    uint256 constant ONE_PCT_SSR  = 1.000000000315522921573372069e27;
    uint256 constant FOUR_PCT_SSR = 1.000000001243680656318820312e27;
    uint256 constant MAX_SSR      = 1.000000021979553151239153027e27;  // 100% APY

    address admin;
    address setter;
    address taker;

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 TAKER_ROLE         = keccak256("TAKER_ROLE");

    MockERC20  asset;
    SparkVault vault;

    // Handler specific storage
    uint256 public constant N = 5;

    address[N] public users;

    mapping(bytes32 => uint256) public numCalls;

    modifier useRandomUser(uint256 lpIndex) {
        address user = users[_bound(lpIndex, 0, users.length - 1)];

        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    constructor(address _vault) {
        vault = SparkVault(_vault);
        asset = MockERC20(vault.asset());

        admin  = vault.getRoleMember(DEFAULT_ADMIN_ROLE, 0);
        setter = vault.getRoleMember(SETTER_ROLE, 0);
        taker  = vault.getRoleMember(TAKER_ROLE, 0);

        for (uint256 i = 0; i < N; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
        }
    }

}
