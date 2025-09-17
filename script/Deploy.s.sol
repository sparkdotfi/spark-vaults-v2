// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Script, console2 } from "forge-std/Script.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Script, console2, stdJson } from "forge-std/Script.sol";
// import { Test }                      from "forge-std/Test.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SparkVault } from "src/SparkVault.sol";

contract DeploySparkVault is Script {

    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    using ScriptTools for string;
    using stdJson     for string;

    function run() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        vm.createSelectFork(getChain("mainnet").rpcUrl);

        string memory config = ScriptTools.loadConfig("input");

        vm.startBroadcast();

        // Deploy SparkVault implementation
        // NOTE: By itself, the Vault has nobody in a privileged role, depositCap and vsr are 0 and
        // initializers are disabled (`constructor() { _disableInitializers(); }`). It is not
        // possible for an outside party to interact with this contract in any way.
        address impl = address(new SparkVault());
        console2.log("SparkVault implementation:", impl, block.number, block.timestamp);

        // Deploy SparkVault proxy for asset0
        console2.log("DeploySparkVault", impl.code.length);
        address proxy_asset0 = address(new ERC1967Proxy(
            impl,
            ""
            // abi.encodeCall(
            //     SparkVault.initialize,
            //     (config.readAddress(".asset0"), config.readString(".name0"), config.readString(".symbol0"), Ethereum.SPARK_PROXY)
            // )
        ));
        // Deploy SparkVault proxy for USDT
        // Deploy SparkVault proxy for WETH

        vm.stopBroadcast();
    }

}
