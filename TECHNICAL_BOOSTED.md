# SparkBoostedVault — Design Notes

## Overview

SparkBoostedVault is a per-user vesting variant of [SparkVault](./src/SparkVault.sol). Each user's yield is gated by a vesting curve defined by two constructor-set durations: **`cliff`** and **`term`**. Principal is always withdrawable; yield is multiplied by a curve that is 0 before `cliff` and then a **quadratic ease-in** `(elapsed/term)²` from 0 to 1 over the `[0, term]` window (with the pre-cliff portion zeroed out — a jump at cliff). Because the ramp is quadratic and slow at the start, early exits forfeit disproportionately more yield than they would under a linear curve.

**Positions are one-shot and locked to msg.sender:**

- Each address holds **at most one position** at a time. Attempting to `deposit` while a position is open reverts.
- `withdraw` is **full-exit only** — closes the entire position and pays out `principal + vested_yield`. Unvested yield is forfeited to the vault.
- `deposit(assets)` credits msg.sender; `withdraw()` burns from and pays msg.sender. There are no receiver/owner override parameters.

There is no ERC20 surface, no allowance system, and no partial-withdraw / top-up logic. To re-stake, fully withdraw and deposit again — the vesting clock resets to `now`.

## Per-user state

```solidity
struct Position {
    uint256 principal;   // asset units the user paid in
    uint256 shares;      // raw rate-based shares; raw_assets = shares * chi / RAY
    uint64  depositTime; // deposit timestamp (T0)
}
```

The `chi` / `rho` / `vsr` rate-accumulator machinery is unchanged from SparkVault — `chi` grows at `vsr` per second.

## The vesting curve

Let `elapsed = block.timestamp - depositTime`. Then:

```
m(elapsed) = 0                        if elapsed <  cliff
m(elapsed) = (elapsed / term)²        if elapsed >= cliff and elapsed < term
m(elapsed) = 1                        if elapsed >= term
```

Geometrically: take the parabola `y = (elapsed/term)²`, clamp at 1 past term, and **zero it out before cliff**. The result is discontinuous — at `elapsed == cliff`, m jumps from 0 to `(cliff/term)²`. After that, m grows quadratically until elapsed reaches term.

Key intuition: at half-term, only **25%** of yield is vested (vs. 50% under linear). At three-quarter term, ~56% is vested (vs. 75% linear). The bulk of the boost is concentrated in the tail near `term`, which makes the curve materially more punishing on early exits than the linear shape.

## Derived quantities

```
raw_assets     = shares * chi / RAY
raw_yield      = max(0, raw_assets - principal)
vested_yield   = raw_yield * m / RAY
unvested_yield = raw_yield - vested_yield
withdrawable   = principal + vested_yield
```

Principal is always claimable, even before cliff. Only yield is gated.

## Mint (deposit)

```
1. drip()                                     // refresh chi
2. shares = assets * RAY / chi
3. Check: msg.sender isn't TAKER
   Check: positions[msg.sender].principal == 0  (no existing position)
   Check: totalAssets + assets <= depositCap
4. Pull `assets` from msg.sender
5. positions[msg.sender] = {
       principal:   assets,
       shares:      shares,
       depositTime: now
   }
6. totalShares    += shares
   totalPrincipal += assets
```

## Burn (withdraw)

```
1. drip()
2. assets = withdrawableOf(msg.sender)        // principal + vested_yield
3. Require assets > 0
4. Read the full position, delete positions[msg.sender]
5. totalShares    -= position.shares
   totalPrincipal -= position.principal
6. Push `assets` to msg.sender
```

The user receives `principal + vested_yield`. The unvested portion of the raw shares (`position.shares * chi / RAY - assets`) stays in the vault and becomes takeable by `TAKER_ROLE`.

---

## Worked example — single position through the curve

`term = 365 days`, `cliff = 90 days`, ~10% APY (treated linearly for arithmetic clarity).

Deposit 100 at t=0. Position: P=100, S=100, T0=0.

| t (days) | raw    | raw_yield | m       | vested | withdrawable | If user withdraws at t |
|----------|--------|-----------|---------|--------|--------------|------------------------|
| 30       | 100.82 | 0.82      | 0       | 0      | 100.00       | gets 100, forfeits 0.82 |
| 89       | 102.44 | 2.44      | 0       | 0      | 100.00       | gets 100, forfeits 2.44 |
| **90**   | 102.47 | 2.47      | 0.0608  | 0.150  | **100.15**   | gets 100.15, forfeits 2.32 |
| 180      | 104.93 | 4.93      | 0.2432  | 1.200  | 101.20       | gets 101.20, forfeits 3.73 |
| 270      | 107.40 | 7.40      | 0.5472  | 4.048  | 104.05       | gets 104.05, forfeits 3.35 |
| 365      | 110.00 | 10.00     | 1.0000  | 10.00  | 110.00       | gets 110, forfeits 0 |
| 730      | 120.00 | 20.00     | 1.0000  | 20.00  | 120.00       | gets 120, forfeits 0 |

Compare with the linear curve at the same times:

| t (days) | m_linear | vested_linear | m_quad  | vested_quad | quad / linear |
|----------|----------|---------------|---------|-------------|---------------|
| 90       | 0.2466   | 0.609         | 0.0608  | 0.150       | 25%           |
| 180      | 0.4932   | 2.432         | 0.2432  | 1.200       | 49%           |
| 270      | 0.7397   | 5.473         | 0.5472  | 4.048       | 74%           |
| 365      | 1.0000   | 10.00         | 1.0000  | 10.00       | 100%          |

A user who exits at t=180 under the quadratic curve receives roughly **half** of what they'd receive under linear — most of the boost is back-loaded into the final stretch before term. The cliff jump at t=90 is also much smaller (0.15 vs 0.61), so even crossing cliff is a relatively modest milestone; the meaningful vesting happens later.

After term the multiplier saturates at 1, and further yield is fully claimable as it accrues. Forfeited yield stays in the vault and becomes TAKER-claimable surplus.

---

## How a user re-stakes

There is no top-up. The flow is:

1. `withdraw()` — closes the position, pays out principal + vested yield, forfeits the unvested portion.
2. `deposit(assets)` — opens a fresh position with `depositTime = now`. Multiplier starts at 0; user must wait through cliff again.

Re-staking after term is always a net loss vs. just holding (you give back the unvested portion at exit, and the new position starts from m=0). Re-staking before term is even worse. The design assumes users hold a position to its natural maturity.

---

## Sybil note

Because the contract uses `msg.sender` as the only identity, a user who wants partial-exit semantics — keep some principal earning yield while withdrawing the rest — can achieve it by splitting deposits across N addresses and fully withdrawing from a subset. The contract has no on-chain defense against this; it's the standard limitation of address-based identity in permissionless DeFi. The "many positions per user" model that this would emulate was the alternative considered during design.

---

## Properties summary

| Property                  | Mechanism                                                                  |
|---------------------------|----------------------------------------------------------------------------|
| Per-user vesting curve    | `m = 0 if elapsed < cliff else min((elapsed/term)², 1)` (quadratic ease-in) |
| Position model            | One per address, one-shot, no top-ups, no partial withdraws                |
| Principal                 | Always paid out on `withdraw()` (even before cliff)                        |
| Forfeited yield           | Stays in vault, takeable by `TAKER_ROLE`                                   |
| Identity binding          | `deposit` and `withdraw` operate on `msg.sender` exclusively               |
| Non-fungible              | No ERC20 surface; no allowance; no transfer                                |
| Upgradeability            | None — `term` / `cliff` / `asset` / `decimals` are `immutable`             |
