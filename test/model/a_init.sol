import { StdUtils, StdCheats, Vm, Test, console, stdError } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IAccessControlEnumerable }
    from "openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

import { IVault } from "src/IVault.sol";

import { VaultDeploy } from "deploy/VaultDeploy.sol";

contract Init is StdUtils, StdCheats {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant SETTER_ROLE = keccak256("SETTER_ROLE");
    bytes32 constant TAKER_ROLE = keccak256("TAKER_ROLE");

    IERC20   asset;
    IVault   proxy;
    IVault   impl;

    address immutable admin;
    address immutable setter;
    address immutable taker;

    uint256 constant N = 5;

    address[N] users;

    mapping(bytes32 => uint256) public numCalls;

    uint256 constant RAY = 10 ** 27;

    constructor() {
        (address _asset, address _proxy, address _impl) = VaultDeploy.deployUsdsToEmptyChain();
        asset = IERC20(_asset); proxy = IVault(_proxy); impl = IVault(_impl);

        // This contract is at first DEFAULT_ADMIN_ROLE.
        IAccessControlEnumerable proxyACE = IAccessControlEnumerable(_proxy);
        require(proxyACE.getRoleMember(DEFAULT_ADMIN_ROLE, 0) == address(this));
        require(proxyACE.getRoleMemberCount(DEFAULT_ADMIN_ROLE) == 1);


        admin = vm.addr(1);
        setter = vm.addr(2);
        taker = vm.addr(3);

        proxyACE.grantRole(DEFAULT_ADMIN_ROLE, admin);
        proxyACE.grantRole(SETTER_ROLE, setter);
        proxyACE.grantRole(TAKER_ROLE, taker);

        for (uint256 i = 4; i < 4 + N; i++) {
            users[i - 4] = vm.addr(i);
        }
    }


    // function warp(uint256 secs) external {
    //     numCalls["warp"]++;
    //     secs = bound(secs, 0, 365 days);
    //     vm.warp(block.timestamp + secs);
    // }
    //
    // function drip() external {
    //     numCalls["drip"]++;
    //     proxy.drip();
    // }
    //
}
