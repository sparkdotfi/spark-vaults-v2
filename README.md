# Spark Vaults V2

![Foundry CI](https://github.com/sparkdotfi/spark-vaults-v2/actions/workflows/merge.yml/badge.svg)
[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/sparkdotfi/spark-vaults-v2/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

Spark Vaults V2 is an ERC4626-compliant yield-bearing vault that implements a continuous rate accumulation mechanism. Users can deposit assets and earn yields through the Vault Savings Rate (VSR), with all interest automatically compounded into their share value. The value created in this vault comes from the ability of a permissioned actor (`TAKER_ROLE`, which is set to be the Spark Liquidity Layer) to pull liquidity and deploy it into yield bearing strategies, and then `transfer` the assets back into the vault to maintain liquidity for withdrawals. The value that this actor owes to the vault at any given time is `assetsOutstanding() = totalAssets() - asset.balanceOf(address(this))`.

Spark Vaults V2 is a fork of sUSDS, sharing much of the same functionality. The key differences between these two contracts are:
- Using OZ AccessControl instead of `rely/deny` and `wards`.
- Introducing new roles:
  - `DEFAULT_ADMIN_ROLE`: Can upgrade the implementation and set `vsr` bounds.
  - `SETTER_ROLE`: Can set the `vsr`.
  - `TAKER_ROLE`: Can remove liquidity from the vault for the purposes of deploying and earning yield.
- Removing all integration with DSS.
- The ability to draw liquidity to deploy into yield bearing strategies with `take`.
- New convenience functions:
  - `nowChi()` returns the current value of the conversion rate at the current timestamp.
  - `assetsOf(address)` returns the underlying value of a given users position at the current timestamp.
  - `assetsOutstanding()` returns the value of assets that are not available as immediate liquidity in the vault at the current timestamp.
- Reordering and styling of functions.

## Features

- **ERC4626 Compliance**: Full implementation of the ERC4626 vault standard.
- **Continuous Rate Accumulation**: Automatic yield distribution through per-second rate accumulation based on a set rate (`vsr`).
- **Referral System**: Built-in referral tracking.
- **Upgradeable**: UUPS upgradeable contract architecture.
- **Role-Based Access Control**: Granular permissions for different operations.
- **EIP-712 Permit Support**: Gasless approvals using EIP-712 signatures.

## Architecture

### Core Components

#### Rate Accumulation System

The vault uses the following rate accumulation mechanism:

- **`chi`**: The rate accumulator that tracks cumulative growth
- **`rho`**: Timestamp of the last rate update
- **`vsr`**: Vault Savings Rate that determines yield generation

#### Mathematical Foundation

- **Rate Formula**: `chi_new = chi_old * (vsr)^(time_delta) / RAY`
- **Asset Calculation**: `totalAssets = totalShares * nowChi() / RAY`

Note that `totalAssets()` has no relation to the current balance of the contract.

### Contract Structure

```
SparkVault
├── AccessControlEnumerableUpgradeable
├── UUPSUpgradeable
└── ISparkVault (IERC20Permit + IERC4626)
```

## Installation & Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Solidity ^0.8.25

### Build

```bash
forge build
```

### Test

```bash
forge test
```

---

<p align="center">
  <img src="https://github.com/user-attachments/assets/799b4fb1-d858-4847-b5f0-4c13741d531a" />
</p>