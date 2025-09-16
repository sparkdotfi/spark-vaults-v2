// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Script, console2 } from "forge-std/Script.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Script, console2, stdJson } from "forge-std/Script.sol";
// import { Test }                      from "forge-std/Test.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { SparkVault } from "src/SparkVault.sol";

contract DeployMorphoMarketMainnet is Script {

    using ScriptTools for string;
    using stdJson     for string;

    function run() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        vm.createSelectFork(getChain("mainnet").rpcUrl);

        vm.startBroadcast();

        string memory config = ScriptTools.loadConfig("input");

        // Deploy SparkVault implementation
        address impl = address(new SparkVault());


    }

}
