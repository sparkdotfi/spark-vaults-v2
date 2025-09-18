// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Script, console2 } from "forge-std/Script.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Script, console2, stdJson } from "forge-std/Script.sol";
// import { Test }                      from "forge-std/Test.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SparkVault } from "src/SparkVault.sol";

contract DeploySparkVaultImpl is Script {

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    using ScriptTools for string;
    using stdJson     for string;

    function run() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
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

        console2.log("Deployed SparkVault implementation:")
        console2.log("  impl: ",            impl);
        console2.log("  block.chainId: ",   block.chainid);
        console2.log("  block.timestamp: ", block.timestamp);
        console2.log("  block.number ",     block.number);
    }

}

contract DeploySparkVaultProxy {
    address impl  = vm.envAddress("SPARK_VAULT_IMPL");
    address admin = Ethereum.SPARK_PROXY;

    function run() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        // Read config
        string memory chainName  = vm.envString("SPARK_VAULT_CHAIN_NAME");
        string memory assetName = vm.envString("SPARK_VAULT_ASSET_NAME");
        string memory fileSlug = string(abi.encodePacked(
            chainName,
            "-",
            assetName
        ));
        string memory inputConfig = ScriptTools.readInput(fileSlug);

        address asset         = inputConfig.readAddress(".asset");
        string  memory name   = inputConfig.readString(".name");
        string  memory symbol = inputConfig.readString(".symbol");

        // Depoy SparkVault proxy
        vm.startBroadcast();
        address proxy = address(new ERC1967Proxy(
            impl,
            abi.encodeCall(
                SparkVault.initialize,
                (asset, name, symbol, admin)
            )
        ));
        vm.stopBroadcast();

        // Log
        console2.log("Deployed SparkVault proxy:");
        console2.log("  proxy: ",     proxy);
        console2.log("  impl:  ",     impl);
        console2.log("  chainName: ", chainName);
        console2.log("  assetName: ", assetName);
        console2.log("  asset: ",     asset);
        console2.log("  name:  ",     name);
        console2.log("  symbol:",     symbol);

    }
}
