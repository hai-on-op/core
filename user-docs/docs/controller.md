# Controller: iRate

The Controller is HAI Protocol’s automated system for adjusting borrowing costs so that HAI trades close to its **floating peg**.

---

## Floating Peg, Not $1

HAI is **not** hard-pegged to $1. Instead, it has a **floating target price** (“redemption price”) that can move slowly over time.  
- If market conditions push HAI away from this target, the Controller changes the cost of borrowing to bring it back in line.  
- The goal is to keep HAI stable relative to its *current* target, rather than force it to $1 at all times.

---

## What the Controller Does

Every few seconds, the Controller:
1. Reads HAI’s **market price** from oracles.
2. Compares it to the **redemption price** (the current target).
3. Updates the **redemption rate** - the per-second interest rate applied to all active HAI debt.

By raising or lowering the redemption rate, the Controller changes the incentive to mint or repay HAI:
- **Price above target** → Borrowing cost decreases → More HAI is minted → Supply expands → Price drifts down.
- **Price below target** → Borrowing cost increases → Minting slows and debt is repaid → Supply contracts → Price drifts up.

---

## iRate (Integral-Only Mode)

The Controller is based on a **PI** (Proportional–Integral) control system:
- **P term** (Proportional) reacts directly to the size of the deviation.
- **I term** (Integral, or iRate) reacts to the *accumulated* deviation over time, with old errors fading out.

In HAI’s current configuration:
- **P term is disabled** (`proportionalGain = 0`).
- **Only the I term is active**, so adjustments are driven by the iRate.

This setup focuses on long-term, sustained deviations rather than short-term volatility, producing smoother, more predictable adjustments.

---

## Why iRate Works for HAI

- **No overreaction** - By ignoring momentary price noise, the system avoids unnecessary swings in borrowing costs.
- **Gradual correction** - Sustained deviations cause stronger adjustments, while brief ones fade away.
- **Market-driven** - Borrowing incentives are adjusted automatically without requiring governance votes or manual intervention.

---

## Example

| Market Price | Redemption Price | Controller Action          | Expected Result                         |
|--------------|------------------|----------------------------|------------------------------------------|
| $1.04        | $1.02             | Lower redemption rate      | Cheaper borrowing → More HAI minted      |
| $1.00        | $1.02             | Slightly higher rate       | Borrowing slows slightly                 |
| $0.97        | $0.99             | Raise redemption rate      | More debt repaid → Supply contracts      |

---

## Key Parameters (Simplified)

While the contract has several tunable settings, the most important for the iRate are:
- **`integralGain`** - How strongly the iRate responds to accumulated deviation.
- **`perSecondCumulativeLeak`** - How quickly past deviations fade from memory.
- **`noiseBarrier`** - Ignores tiny deviations so the rate doesn’t change unnecessarily.
- **Bounds** - Hard limits on how high or low the redemption rate can move.

---

In short:  
**The iRate is HAI’s quiet steering wheel - adjusting borrowing costs just enough to keep HAI’s floating peg steady without heavy-handed intervention.**
