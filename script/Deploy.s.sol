// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Script, console2, stdJson } from "forge-std/Script.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { ERC1967Proxy }   from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SparkVault } from "src/SparkVault.sol";

contract DeploySparkVaultImpl is Script {

    using ScriptTools for string;
    using stdJson     for string;

    function run() public {
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        // TODO: Figure out why this doesn't work. Until then, --rpc-url must be passed to `forge
        // script` manually
        // vm.createSelectFork(getChain("mainnet").rpcUrl);

        // Deploy SparkVault implementation
        vm.startBroadcast();
        // NOTE: By itself, the Vault has nobody in a privileged role, depositCap and vsr are 0 and
        // initializers are disabled (`constructor() { _disableInitializers(); }`). It is not
        // possible for an outside party to interact with this contract in any way.
        address impl = address(new SparkVault());
        vm.stopBroadcast();

        console2.log("Deployed SparkVault implementation:");
        console2.log("  impl: ",            impl);
        console2.log("  block.chainId: ",   block.chainid);
        console2.log("  block.timestamp: ", block.timestamp);
        console2.log("  block.number ",     block.number);
    }

}

contract DeploySparkVaultProxy is Script {

    using ScriptTools for string;
    using stdJson     for string;

    address impl  = vm.envAddress("SPARK_VAULT_IMPL");

    function run() public {
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        // Read config
        string memory chainName = vm.envString("SPARK_VAULT_CHAIN_NAME");
        string memory assetName = vm.envString("SPARK_VAULT_ASSET_NAME");
        string memory fileSlug  = string(abi.encodePacked(
            chainName,
            "-",
            assetName
        ));
        string memory inputConfig = ScriptTools.readInput(fileSlug);

        address admin         = inputConfig.readAddress(".admin");
        address asset         = inputConfig.readAddress(".asset");
        string  memory name   = inputConfig.readString(".name");
        string  memory symbol = inputConfig.readString(".symbol");

        // Deploy SparkVault proxy
        vm.startBroadcast();
        SparkVault proxy = SparkVault(address(new ERC1967Proxy(
            impl,
            abi.encodeCall(
                SparkVault.initialize,
                (asset, name, symbol, admin)
            )
        )));
        vm.stopBroadcast();

        // Check
        require(proxy.asset() == asset, "asset");

        require(proxy.decimals() == IERC20Metadata(asset).decimals(), "decimals");

        require(keccak256(bytes(proxy.name()))   == keccak256(bytes(name)),   "name");
        require(keccak256(bytes(proxy.symbol())) == keccak256(bytes(symbol)), "symbol");

        require(proxy.getRoleMemberCount(proxy.DEFAULT_ADMIN_ROLE()) == 1, "admin count");
        require(proxy.hasRole(proxy.DEFAULT_ADMIN_ROLE(), admin),          "admin role");

        require(proxy.getRoleMemberCount(proxy.SETTER_ROLE()) == 0, "setter count");
        require(proxy.getRoleMemberCount(proxy.TAKER_ROLE())  == 0, "taker count");

        require(proxy.chi()        == 1e27,            "chi");
        require(proxy.rho()        == block.timestamp, "rho");
        require(proxy.vsr()        == 1e27,            "vsr");
        require(proxy.minVsr()     == 1e27,            "minVsr");
        require(proxy.maxVsr()     == 1e27,            "maxVsr");
        require(proxy.depositCap() == 0,               "depositCap");

        // Log
        console2.log("Deployed SparkVault proxy:");
        console2.log("  proxy: ",     address(proxy));
        console2.log("  impl:  ",     impl);
        console2.log("  chainName: ", chainName);
        console2.log("  assetName: ", assetName);
        console2.log("  asset: ",     asset);
        console2.log("  name:  ",     name);
        console2.log("  symbol:",     symbol);
    }

}
