// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.29;

import { ERC20Mock } from "openzeppelin-contracts/mocks/token/ERC20Mock.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { Vault } from "src/Vault.sol";

library VaultDeploy {
    // --- Empty chain deployments ---
    function deployUsdsToEmptyChain() internal returns (address asset, address proxy, address impl) {
        asset = address(new ERC20Mock()); // Return param
        string memory name = "Spark USDS";
        string memory symbol = "spUSDS";
        (proxy, impl) = deployToEmptyChain(asset, name, symbol); // Return params
    }

    function deployToEmptyChain(
        address asset, string memory name, string memory symbol
    ) internal returns (address proxy, address impl) {
        // On empty chain, admin is `this`
        address admin = address(this);
        (proxy, impl) = deploy(asset, name, symbol, admin); // Return params
    }

    // --- Exsting chain deployments ---

    function deployUsdsToMainnet() internal returns (address proxy, address impl) {
        // Set the asset, name, and symbol.
        address asset = Ethereum.USDS;
        string memory name = "Spark USDS";
        string memory symbol = "spUSDS";
        (proxy, impl) = deployToMainnet(asset, name, symbol); // Return params
    }

    function deployToMainnet(
        address asset, string memory name, string memory symbol
    ) internal returns (address proxy, address impl) {
        // On mainnet, admin is `SPARK_PROXY`.
        address admin = Ethereum.SPARK_PROXY
        (proxy, impl) = deploy(asset, name, symbol, admin); // Return params
    }

    // TODO Other chains will go here.

    function deploy(
        address asset, string memory name, string memory symbol, address admin
    ) internal returns (address proxy, address impl) {
        // Deploy the implementation and proxy.
        impl = address(new Vault(asset)); // Return param
        // Return param
        proxy = address(new ERC1967Proxy(impl, abi.encodeCall(Vault.initialize, (name, symbol, admin))));

        // TODO Set ssr-setter and taker.
    }
}
