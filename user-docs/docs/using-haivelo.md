# haiVELO Documentation

- **haiVELO v1 contract address:**
- **haiVELO v2 contract address:**
- **haiVELO reserve address:**

## Overview

**haiVELO** is a **veVELO** wrapper, natively issued by the HAI Protocol. It transforms VELO into a composable, transferable token that captures veVELO voting rewards while enabling users to mint HAI stablecoins against it.

Unlike third-party wrappers, haiVELO is an official collateral type hard pegged to VELO in the HAI CDP system. It offers yield, liquidity, and utility.

## What Is haiVELO?

haiVELO represents a user’s share of the protocol’s locked veVELO position. That veVELO earns **voting rewards** (bribes + trading fees) on Velodrome, which are converted into HAI and distributed to users who **deposit haiVELO as collateral**.

In **haiVELO v1**:
- Only VELO is accepted for minting haiVELO.
- Rewards come from protocol veVELO votes on incentivized pools.
- Users must **deposit haiVELO into a HAI vault** to earn yield and mint HAI.

In **haiVELO v2**:
- VELO, veVELO NFTs, and haiVELO v1 are accepted for minting haiVELO v2.
- Both haiVELO v1 & v2 will continue to be accepted as collateral and earn veVELO rewards.

## How HAI Protocol Works

HAI is a decentralized stablecoin protocol based on CDPs (collateralized debt positions). Users deposit collateral (like haiVELO) into vaults and mint HAI against it.

haiVELO acts as both:
- A **collateral type** to mint HAI.
- A **yield-bearing token** representing access to protocol veVELO rewards.

## How haiVELO Works

1. **Convert VELO and veVELO**
   - Users convert VELO and veVELO 1:1 in the haiVELO minting interface
   - The protocol permanently locks it into veVELO NFTs for maximum voting power
   - **Minting haiVELO is a one-way, irreversible action**
2. **Receive haiVELO**
   - haiVELO is minted 1:1 and sent to the user
3. **Deposit haiVELO into a Vault**
   - Users must deposit haiVELO into a HAI vault to:
     - Earn veVELO voting rewards
     - Borrow (Mint) HAI
4. **Earn Voting Rewards (Bribes + Fees)**
   - The HAI Protocol earns **veVELO voting rewards once per week** (Velodrome epochs are 7 days)
   - Voting strategies are optimized across the Superchain to maximize rewards
   - These rewards are:
     - Converted into HAI
     - Broken into 7 equal parts
     - Distributed **daily** to haiVELO depositors
     - A 10% performance fee goes towards a protocol owned HAI reserve
5. **Claim Rewards**
   - There is a **7 day warm-up period** before deposits start earning rewards
   - Rewards are **claimable once every 24 hours**
   - Distribution is based on vault balances from the **previous Velodrome epoch**
6. **Boost with KITE**
   - Users can stake KITE to **boost haiVELO positions up to 2×**
   - KITE stakers also earn protocol fees in HAI
7. **Borrow Against haiVELO**
   - Deposit haiVELO → mint HAI → use however you want
   - Borrowers earn KITE emissions to stake → boost → flywheel

## Reward Distribution Details

| Mechanism                  | Details                                                                 |
|---------------------------|-------------------------------------------------------------------------|
| Velodrome Epoch Duration  | 7 days                                                                  |
| Reward Source             | Voting rewards (bribes + trading fees)                                  |
| Earned By Protocol        | Once per epoch (weekly)                                                 |
| Distributed To Users      | Daily, proportional to vault balances                                               |
| Based On                  | haiVELO vault balances from previous epoch                              |
| Claimable Frequency       | Once every 24 hours                                                     |

## Strategy Loops

haiVELO enables powerful composable strategies:

### Leveraged LP Strategy
1. Convert VELO → receive haiVELO
2. Deposit haiVELO into vault → earn daily HAI rewards
3. Borrow HAI → provide liquidity on Velodrome
4. Earn VELO emissions → convert into haiVELO
5. Earn KITE emissions → stake to increase boost
6. Repeat → flywheel spins

### Leveraged Looping Strategy
1. Convert VELO → receive haiVELO
2. Deposit haiVELO into vault → earn daily HAI rewards
3. Borrow HAI → buy VELO
4. Loop into haiVELO to maximize veVELO + KITE rewards

## Summary of Benefits

- **Liquid veVELO Exposure**: Tradable, backed by protocol-locked veVELO
- **Daily Yield**: HAI rewards paid daily from bribes and fees
- **Boostable Returns**: Use KITE to double yield
- **Capital Efficiency**: Borrow HAI while earning yield
- **Composability**: Integrate haiVELO into broader DeFi strategies

## How It Compares

| Token       | Backed&nbsp;By                               | Source&nbsp;of&nbsp;Yield                                      | Tradable | Voting&nbsp;Power                      | Boostable          | Reward&nbsp;Claim                 | Collateralized               | Peg Stability                               |
| ------------------ | --------------------------------------- | ------------------------------------ | -------- | --------------------------------- | ------------------ | --------------------------- | ------------------------- | ---------------------------------- |
| **haiVELO** | veVELO                   | Velodrome bribes + trading fees | ✅ Yes    | ✅ Protocol votes on user's behalf | ✅&nbsp;via&nbsp;KITE         | Daily in HAI stablecoins | ✅ Yes (natively) | ✅ Hard&nbsp;pegged to VELO as collateral     |
| **yCRV**    | veCRV               | Curve trading fees, crvUSD fees, bribes    | ✅ Yes    | ❌ No                              | ❌ No                  | Weekly in crvUSD or auto-compounded    | ❌ No            | ❌ Often trades at 50%+ discount  |
| **cvxCRV**  | veCRV                | Curve trading fees, crvUSD fees, bribes + native fees      | ✅ Yes    | ✅ via Convex voting               | ✅ via CVX staking  | Accumulate in CRV, crvUSD, CVX          | ❌ No            | ❌ Often trades at 50%+ discount |
| **auraBAL** | veBAL | BAL incentives + bribes | ✅ Yes    | ✅ via Aura voting                 | ❌ No | Accumulate in BAL + AURA or auto-compounded            | ❌ No            | ❌ Depends on auto-compounding     |

## Collateral Risk and Liquidation

While **haiVELO is hard-pegged to the price of VELO** through its 1:1 backing, it's important to remember that **VELO itself is a volatile asset**. This means users who borrow against haiVELO must actively **monitor and manage their vaults** to ensure their collateralization remains healthy.

### Maintaining Vault Health

Each HAI vault that uses haiVELO as collateral must maintain a **minimum collateralization ratio of 200%** (subject to change through governance). If the value of VELO drops or if borrowed HAI increases disproportionately, the vault's ratio may fall below this threshold. When this happens, the vault becomes eligible for **liquidation**.

### Liquidation Process

If a vault falls below the minimum ratio:
- It can be **liquidated via auction** through the HAI protocol’s [Collateral Auction House](https://docs.letsgethai.com/detailed/auctions/cah.html).
- Liquidated collateral is sold to the highest bidder, who pays **HAI** to cover the outstanding debt.
- This mechanism helps restore solvency and keeps the system overcollateralized.

### Protocol Safety Reserve

To further protect the system, HAI Protocol builds a **reserve of HAI** funded by a **10% performance fee** on rewards earned from the haiVELO collateral type. This reserve acts as a backstop to cover **any potential bad debt** in the event a liquidation auction cannot fully cover a vault’s obligations.

### Key Points

- **haiVELO is pegged to VELO**, but VELO is still volatile.
- Keep your vault **well above 200% collateralization** to avoid liquidation.
- Liquidated positions are **auctioned for HAI** to repay system debt.
- The protocol maintains a **reserve buffer** from rewards to manage risks.


## haiVELO v1 Collateral Parameters

### General

| Parameter       | Value                                     |
|----------------|-------------------------------------------|
| Version         | haiVELO v1                                |
| Token Address   | [0x70f3713512089736661F928B291d1443C8b1BB6A](https://optimistic.etherscan.io/token/0x70f3713512089736661F928B291d1443C8b1BB6A) |

---

### [Collateral Auction House](https://docs.letsgethai.com/detailed/auctions/cah.html)

| Parameter                         | Value        |
|----------------------------------|--------------|
| `minimumBid`                     | 100 HAI      |
| `minDiscount`                    | 0% (no discount) |
| `maxDiscount`                    | 40%          |
| `perSecondDiscountUpdateRate`   | 6 hours      |

---

### Oracle / Price Feed

| Description              | Details                                                           |
|--------------------------|-------------------------------------------------------------------|
| Oracle Compatibility     | UNI v3 or Chainlink aggregator compatible                         |
| Price Feed   | [0xF4d48d48C177C4CcBb95F8cbe62619A80a992A99](https://optimistic.etherscan.io/address/0xf4d48d48c177c4ccbb95f8cbe62619a80a992a99#readContract)            |

---

### [SAFEEngine](https://docs.letsgethai.com/detailed/modules/safe_engine.html)

| Parameter       | Value     |
|----------------|-----------|
| `debtCeiling`   | 100,000 HAI |
| `debtFloor`     | 150 HAI   |

---

### [Oracle Relayer](https://docs.letsgethai.com/detailed/modules/oracle_relayer.html)

| Parameter             | Value   |
|-----------------------|---------|
| `safetyCRatio`        | 220%    |
| `liquidationCRatio`   | 200%    |

---

### [TaxCollector](https://docs.letsgethai.com/detailed/modules/tax_collector.html)

| Parameter         | Value |
|-------------------|-------|
| `stabilityFee`    | 5%    |

---

### [LiquidationEngine](https://docs.letsgethai.com/detailed/modules/liq_engine.html)

| Parameter             | Value       |
|-----------------------|-------------|
| `liquidationPenalty`  | 20%         |
| `liquidationQuantity` | 50,000 HAI  |


## TL;DR

haiVELO is a native wrapper of veVELO issued by the HAI Protocol. Convert VELO → receive haiVELO → deposit it as collateral in a vault → earn daily HAI rewards from bribes and fees. Claim rewards every 24h. Boost yield with KITE. Borrow HAI. Loop it. Flywheel go brr.
