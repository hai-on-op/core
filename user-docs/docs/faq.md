# Frequently Asked Questions (FAQ)

## What is HAI?
HAI is an overcollateralized stable asset built on Optimism.  
It is **not pegged to $1** - instead, it uses a floating peg managed by the protocol’s controller to balance supply and demand.  

---

## How do I mint HAI?
You can mint HAI by depositing approved collateral into the protocol and opening a vault.  
Your borrowing capacity depends on the collateral type’s minimum collateral ratio (MCR).  
See the [Minting HAI](./minting-hai.mdx) guide for step-by-step instructions.

---

## What is haiVELO?
haiVELO is a perpetual yield token backed by protocol-owned veVELO.  
When you deposit haiVELO as collateral, you earn yield from veVELO voting rewards - paid in HAI - and may also earn additional KITE incentives.

---

## How does KITE staking work?
Staking KITE:
- Boosts haiVELO deposit rewards  
- Boosts minting incentives for certain collateral types  
- Earns a share of protocol fees (paid in HAI)  

KITE staking does **not** give governance power. See the [KITE Staking](./kite-staking.md) page for details.

---

## What is the Stability Pool?
The Stability Pool is used to absorb undercollateralized positions automatically.  
When a vault is liquidated, its debt is canceled with HAI from the Stability Pool, and the collateral is distributed to Stability Pool depositors.  
This helps maintain peg stability without relying solely on public auctions.

---

## What is the Controller?
The Controller adjusts the protocol’s **interest rate (iRate)** dynamically to help keep HAI’s market price near its floating target.  
If HAI trades above target, iRate may increase to encourage borrowing and expand supply.  
If HAI trades below target, iRate may decrease to reduce borrowing incentives and slow supply growth.  
P and D rates are disabled in HAI, so only iRate adjustments are active.

---

## Is HAI safe?
No protocol is risk-free but HAI has been audited by some of the best in the industry.

Risks include:
- Smart contract vulnerabilities
- Collateral price volatility
- Extreme market conditions leading to rapid liquidations

Always do your own research.

---

## On which network does HAI operate?
HAI runs on **Optimism**, an Ethereum Layer 2. You’ll need a wallet that supports the Optimism network (e.g., MetaMask, Rabby) to interact with the protocol.

---

## Where can I get support?
You can join the [HAI Discord](https://discord.gg/letsgethai) or reach out on [Twitter/X](https://x.com/letsgethai).
