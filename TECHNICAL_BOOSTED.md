# SparkBoostedVault — Design Notes

## Overview

SparkBoostedVault is a per-user vesting variant of [SparkVault](./src/SparkVault.sol). Each user's yield is gated by a vesting curve defined by two constructor-set durations: **`cliff`** and **`term`**. Principal is always withdrawable; yield is multiplied by a curve that is 0 before `cliff` and then linear from 0 to 1 over the entire `[0, term]` window (with the pre-cliff portion zeroed out — a jump at cliff).

Positions are non-fungible: there's no ERC20 surface. A user has at most one position; subsequent deposits or partial withdraws mutate it via the time-blending rules below.

## Per-user state

```solidity
struct Position {
    uint256 principal;   // asset units the user has paid in (minus withdrawn principal)
    uint256 shares;      // raw rate-based shares; raw_assets = shares * chi / RAY
    uint64  depositTime; // effective deposit timestamp (T0)
}
```

The `chi` / `rho` / `vsr` rate-accumulator machinery is unchanged from SparkVault — `chi` grows at `vsr` per second.

## The vesting curve

Let `elapsed = block.timestamp - depositTime`. Then:

```
m(elapsed) = 0                        if elapsed <  cliff
m(elapsed) = elapsed / term           if elapsed >= cliff and elapsed < term
m(elapsed) = 1                        if elapsed >= term
```

Geometrically: take the line `y = elapsed/term`, clamp at 1 past term, and **zero it out before cliff**. The result is discontinuous — at `elapsed == cliff`, m jumps from 0 to `cliff/term`. After that, m grows linearly.

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
3. Check: receiver isn't TAKER, totalAssets + assets <= depositCap
4. Pull `assets` from msg.sender
5. Blend depositTime:
       if oldPrincipal == 0:
           newT0 = now
       else:
           newT0 = (oldPrincipal * oldT0 + assets * now) / (oldPrincipal + assets)
6. principal += assets
   shares    += shares_minted
   totalShares    += shares_minted
   totalPrincipal += assets
```

## Burn (withdraw)

```
1. drip()
2. withdrawable = principal + vested_yield
3. Require: assets <= withdrawable, owner == msg.sender
4. f = assets * RAY / withdrawable          // withdrawal fraction in ray
5. sharesBurned    = shares    * f / RAY
   principalBurned = principal * f / RAY
6. newT0 = oldT0 + f * (now - oldT0) / RAY  // blend toward now by f
7. Update position, decrement totals
8. Push `assets` to receiver
```

The user always receives exactly `assets`. Shares are reduced by `f`; the gap between `sharesBurned * chi / RAY` and `assets` is the **proportional unvested yield**, which stays in the vault and is takeable by `TAKER_ROLE`.

---

## Why it works — worked examples

Throughout: `term = 365 days`, `cliff = 90 days`, and a simplified ~10% APY (treated linearly for arithmetic clarity; the real contract compounds via `_rpow`, but the conclusions are identical).

### Example 1 — Single deposit through the curve

Deposit 100 at t=0. Position: P=100, S=100, T0=0.

| t (days) | raw    | raw_yield | m       | vested | withdrawable |
|----------|--------|-----------|---------|--------|--------------|
| 30       | 100.82 | 0.82      | 0       | 0      | 100.00       |
| 89       | 102.44 | 2.44      | 0       | 0      | 100.00       |
| **90**   | 102.47 | 2.47      | 0.2466  | 0.609  | **100.61**   |
| 180      | 104.93 | 4.93      | 0.4932  | 2.432  | 102.43       |
| 365      | 110.00 | 10.00     | 1.0000  | 10.00  | 110.00       |
| 730      | 120.00 | 20.00     | 1.0000  | 20.00  | 120.00       |

The **jump at t=90** is intentional: the cliff is a commitment threshold. A user who exits at t=89 walks away with only their principal; one who waits one block longer is paid out 0.609 in one go and then continues vesting linearly. After t=365 the multiplier saturates at 1, and further yield is fully claimable as it accrues.

### Example 2 — Why principal-weighted blending is the right T0 rule

Deposit 100 at t=0 (T0=0). At t=200, deposit another 100.

**Principal-weighted blend:**
```
newT0 = (100·0 + 100·200) / 200 = 100
```

T0 lands at the midpoint between the two deposit times — exactly what you'd expect when each dollar of principal carries equal weight in determining the effective deposit age.

If the second deposit is larger (300 instead of 100):
```
newT0 = (100·0 + 300·200) / 400 = 150
```
T0 sits 3/4 of the way toward 200 because the new deposit dominates by weight. This is a literal weighted average of principal-days: 100 dollar-days at age 0, plus 300 dollar-days at age 200, averaged over total principal.

**Why not weight by current value (principal + accrued yield)?**

That would inflate the old position's weight by however much chi has grown, dragging T0 less forward. Two problems:
1. The blend would depend on the chi path — two users making the same deposits with the same timing could end up with different T0s depending on rate history.
2. Yield is already credited to the user via the shares balance. Weighting by value would *also* reward it via softer T0 movement — double-counting.

Principal-weight is the only blend that depends purely on user actions (deposit amounts + timestamps) and is independent of the rate path.

### Example 3 — Why proportional burn works (full + partial)

Position: P=100, S=100, T0=0 (chi(0) ≡ 1.0). At t=365, chi=1.1: raw=110, yield=10, m=1, withdrawable=110.

**Full withdraw of 110:**
- `f = 110/110 = 1.0`
- `sharesBurned = 100`, `principalBurned = 100`
- `newT0 = 0 + 1.0·365 = 365` (irrelevant — position is empty)
- Push 110 to user. Position cleanly closes.

**Half withdraw of 55** (at t=365):
- `f = 55/110 = 0.5`
- `sharesBurned = 50`, `principalBurned = 50`
- `newT0 = 0 + 0.5·365 = 182.5`
- New position: P=50, S=50, T0=182.5.

**Sanity-check the remaining half immediately after:**
- raw = 50·1.1 = 55, yield = 5
- elapsed = 365 − 182.5 = 182.5, so m = 0.5
- vested = 2.5, withdrawable = **52.5**

The user pulled 55 and could pull another 52.5 right now: total = 107.5, vs. the 110 they had pre-withdraw. The missing 2.5 is the proportional unvested yield forfeited by burning half the shares while shifting T0 forward.

**The penalty over time** — compare two strategies starting from P=100 at t=0, chi(0)=1, chi(365)=1.1, chi(730)=1.2:
- **Hold to t=730:** raw=120, yield=20, m=1 → claim 120.
- **Half-withdraw at t=365, hold rest to t=730:** claim 55 at t=365. Remaining position (P=50, S=50, T0=182.5): at t=730, raw=60, yield=10, elapsed=547.5 > term → m=1 → claim 60. Total = 55 + 60 = **115**.

Holding to term is worth 5 more units than splitting the exit. That 5 sits in the vault and is takeable by `TAKER_ROLE` — the contract's "exit tax" is captured as protocol surplus.

### Example 4 — Top-up after vesting completes

Deposit 100 at t=0; at t=400 fully vested (m=1, withdrawable ≈ 110.96).

Top up another 100 at t=400:
- `newT0 = (100·0 + 100·400) / 200 = 200`
- elapsed at t=400 is now 400 − 200 = **200 days**
- new m = 200/365 ≈ 0.548 — back below 1
- combined P=200, raw ≈ 210.96, yield ≈ 10.96
- vested = 10.96 · 0.548 ≈ **6.01**

The user's claimable yield just dropped from 10.96 to ~6.01 — they "gave back" ~4.95 of vested status to top up. This is the cost of merging into a single position: the new principal dilutes the vesting of the existing principal.

The alternative (withdraw first, then redeposit fresh) is worse: it would reset T0 entirely to 400, pushing m to 0 until cliff. Top-up is the cheaper path even with the dilution.

If you want **no dilution** on additional deposits, you'd need the "many positions per user" model — which was rejected for storage / UX reasons. The dilution is inherent to one-position-per-user.

### Example 5 — TAKER's effective claim

The vault's asset balance can exceed `sum(withdrawableOf(user))` for two reasons:
1. **Unvested yield** that hasn't yet vested for users — could become claimable later.
2. **Forfeited yield** from prior partial withdraws and full exits — permanently unclaimable by any user.

On-chain storage doesn't distinguish them; both just live as `assetBalance − totalUserClaimable`. `take(value)` pulls liquidity directly, so off-chain risk processes must ensure TAKER only pulls genuine surplus, not future-vesting headroom.

`totalAssets()` is computed as `totalShares · chi / RAY` — the **raw** obligation, ignoring the multiplier. That overstates what's owed (some of it will never vest) but is the safe direction for the deposit-cap check and for `assetsOutstanding`.

---

## Properties summary

| Property                  | Mechanism                                                                  |
|---------------------------|----------------------------------------------------------------------------|
| Per-user vesting curve    | `m = 0 if elapsed < cliff else min(elapsed/term, 1)`                       |
| Multiple deposits         | T0 blended by **principal** weight                                         |
| Partial withdraws         | T0 shifted toward now by withdrawal fraction `f`; shares + principal burned proportionally |
| Forfeited yield           | Stays in vault, takeable by `TAKER_ROLE`                                   |
| Principal                 | Always withdrawable, never locked                                          |
| Non-fungible              | No ERC20 surface; no allowance; `withdraw` requires `owner == msg.sender`  |
| Upgradeability            | None — `term` / `cliff` / `asset` / `decimals` are `immutable`             |

The "tax on exit" structure rewards committed depositors: long-held, single-deposit positions get full vesting; churning or frequent top-ups leak yield to the protocol. All math is self-consistent under chi-based accounting and requires no off-chain coordination beyond TAKER hygiene.
