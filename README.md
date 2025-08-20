# Spark Vaults V2

[![Foundry][foundry-badge]][foundry]
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://github.com/{org}/{repo}/blob/master/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

Spark Vaults V2 is an ERC4626-compliant yield-bearing vault that implements a continuous rate accumulation mechanism. Users can deposit assets and earn yields through the Spark Savings Rate (SSR), with all interest automatically compounded into their share value.

## Features

- **ERC4626 Compliance**: Full implementation of the ERC4626 vault standard
- **Continuous Rate Accumulation**: Automatic yield distribution through chi
- **Referral System**: Built-in referral tracking
- **Upgradeable**: UUPS upgradeable contract architecture
- **Role-Based Access Control**: Granular permissions for different operations
- **EIP-712 Permit Support**: Gasless approvals using EIP-712 signatures

## Architecture

### Core Components

#### Rate Accumulation System

The vault uses the following rate accumulation mechanism:

- **Chi**: The rate accumulator that tracks cumulative growth
- **Rho**: Timestamp of the last rate update
- **SSR**: Spark Savings Rate that determines yield generation

#### Mathematical Foundation

- **Rate Formula**: `chi_new = chi_old * (ssr)^(time_delta) / RAY`
- **Asset Calculation**: `user_assets = user_shares * nowChi() / RAY`

### Contract Structure

```
SparkVault
├── AccessControlEnumerableUpgradeable
├── UUPSUpgradeable
└── ISparkVault (IERC20Permit + IERC4626)
```

## Access Control

The vault implements role-based access control:

- **DEFAULT_ADMIN_ROLE**: Can upgrade contracts, set SSR bounds, grant/revoke roles
- **SETTER_ROLE**: Can update the Spark Savings Rate
- **TAKER_ROLE**: Can withdraw assets from the vault

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
