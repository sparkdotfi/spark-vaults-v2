// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { Test, console2 as console } from "forge-std/Test.sol";

import { ERC20Mock as MockERC20 } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { SparkVault } from "src/SparkVault.sol";

contract Init is Test {
    uint256 constant RAY = 10 ** 27;

    // Common storage
    uint256 constant ONE_PCT_VSR  = 1.000000000315522921573372069e27;
    uint256 constant FOUR_PCT_VSR = 1.000000001243680656318820312e27;
    uint256 constant MAX_VSR      = 1.000000021979553151239153027e27;  // 100% APY

    address admin;
    address setter;
    address taker;

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 SETTER_ROLE        = keccak256("SETTER_ROLE");
    bytes32 TAKER_ROLE         = keccak256("TAKER_ROLE");

    MockERC20  asset;
    SparkVault vault;

    // Handler specific storage
    mapping(bytes32 => uint256) public numCalls;

    uint256 public constant N = 5;

    address[N] public users;

    mapping (address user => uint256 lastBalance) public lastBalanceOf;
    mapping (address user => uint256 lastAssets)  public lastAssetsOf;

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

    function getRandomUser(uint256 userIndex) internal returns (address user) {
        user = users[_bound(userIndex, 0, users.length - 1)];
        vm.startPrank(user);
        return user;
    }

}
