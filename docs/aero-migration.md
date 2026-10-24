# New AERO / sAERO migration contracts

These contracts prepare a new Base haiAERO principal receipt and separate Base/Optimism legacy-claim migrators. They do not upgrade existing wrappers, migrate treasury assets, deploy a bridge, onboard HAI collateral, or move SAFE debt. All new contracts deploy paused. No production deployment is represented by the example manifest.

## Source and chain identity

The minimal upstream interfaces are derived from `dromos-labs/metadex-public` commit `8b506b450aaa9d4a9f1a77e264f2d9dd508e9ddf`, checked against verified deployed sources and runtime hashes at Base block `53038227`.

| Base dependency | Address | Runtime hash |
| --- | --- | --- |
| New AERO | `0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee` | `0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9` |
| sAERO | `0xBF7977E1521e9a3032bf7243Ee4712f311f13915` | `0x1474067e90b379bf030a4b67292648a6873bb2c5ce0ae1eb64b4e3b21b5be87e` |
| Root Voter | `0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6` | `0x8a5513b4047058fcc5d8b6ae28f46a1ba03d95e31855ab202fa5e4a9f2e01b1b` |

The deployment script fails if these runtimes or the escrow's TOKEN/VOTER bindings change. The user-approved collateral policy reuses the existing HAIAERO Pyth AERO/USD oracle; the preparation script verifies its exact live binding and runtime rather than inferring identity from a symbol.

## Treasury Safe custody

`HaiAero` uses the same custody model as the existing products: an immutable treasury Safe holds and manages the backing NFTs. The Safe can vote, claim rewards, transfer NFTs and migrate backing through future protocol upgrades. The issuer has no privileged mint and no generic execution function. There is no delayed retirement mechanism or new wrapper-controlled custody restriction.

Deposits of new AERO create permanent sAERO with `createStake(amount, 0, true)`, transfer the resulting NFT to the Safe, verify its received principal and mint only then. Existing NFTs must have `staked(id).amount > 0`, `isPermanent == true`, `end == 0`, and be owned by the caller. They transfer directly to the Safe before minting. Amount means principal, not NFT count, voting power or delegated weight.

The Safe can deliberately recognize its own already-migrated sAERO by calling `depositNFTs` itself. This authenticated intake does not require approval or a self-transfer that might reset delegation. The NFT must actually be owned by the immutable Safe and permanently staked, and its tokenId must never have been recognized before. An unrelated caller cannot mint against the Safe's existing holdings. Each tokenId is recognized once even if the Safe later transfers it away and a holder attempts to redeposit it.

The tokenId check does **not** prevent a trusted Safe from splitting, merging or otherwise moving previously recognized principal into a new NFT ID and recognizing it again. That would issue duplicate claims against the same economic backing. Treasury operations must prohibit recycling previously issued principal through any new-ID intake. Initial migration intake must list specifically selected, previously unissued migrated NFTs. There is no automatic global backing-identity oracle or existing-receipt burn-and-reissue mechanism here; a future replacement-ID workflow requires separately reviewed reconciliation. A test explicitly demonstrates this trust limitation.

Treasury custody is an explicit trust assumption. `totalIssuedPrincipal` and `principalOf(id)` record issuance, not a live guarantee that the Safe still owns the original positions. `backingOf(id)` returns the live permanent principal only while the Safe owns that original NFT, otherwise zero. `backingStatus(id)` separates recorded principal, live principal and actual Safe ownership. A deliberate future treasury migration needs a separately reconciled backing inventory; old NFT records alone do not establish the replacement backing.

The issuer owner can pause and unpause deposits. Voting, allocation, reward recipients, approvals and backing migration remain under the Safe's normal multisig controls, with no issuer operator role. Users cannot redeem haiAERO through this one-way issuer. Unsolicited safe transfers to the issuer revert; unsafe direct transfers to it mint nothing and are not recoverable through this contract.

## Bearer migration and the unpausable legacy deposit tail

`HaiAeroMigrator` permanently holds surrendered legacy ERC20s and transfers already-issued new haiAERO. It never mints. There is no holder snapshot, wallet allowlist or claim expiry. The bearer of an eligible token can migrate, including a proxy holding withdrawn SAFE collateral. This does not itself implement debt-safe migration.

Canonical routes and immutable rates:

| Chain | Source | Output per source |
| --- | --- | --- |
| Optimism | haiVELO v1 `0x70f3713512089736661F928B291d1443C8b1BB6A` | `44 / 1000` |
| Optimism | haiVELO v2 `0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6` | `44 / 1000` |
| Optimism | Legacy synthetic haiAERO `0xbdF4A4Cc124d9A83a5774574fcBE45DC5d1f1152` | `1 / 1` |
| Base | Legacy native haiAERO `0x10398AbC267496E49106B07dd6BE13364D10dC71` | `1 / 1` |

Before activation and before/after every exchange:

```
economicOutstanding = totalSupply - balanceOf(dead) - balanceOf(thisMigrator)
Base legacy haiAERO also subtracts balanceOf(the known legacy Base bridge)
requiredOutput = sum(ceil(economicOutstanding * numerator / denominator))
inventory >= requiredOutput
remaining source caps >= each source's economicOutstanding
```

The only bridge exclusion is `0xD605046D24CdaD37Ca2Dff3aa8Ebf254CeEe86d5` for the Base legacy haiAERO route; those claims are represented by Optimism synthetic supply. v1 transferred to `0xdead` has become v2 and is excluded to avoid double counting. Surrendered tokens cannot be rescued or used to mint another receipt. Source cap increases are allowed only while paused; rates and exclusions cannot change.

Legacy direct minting and incoming legacy bridge messages can increase liabilities at any time. The dynamic gate blocks **every route** until the new liability is fully backed and caps cover it, even if the caller's small quote would fit in inventory. This deliberately sacrifices availability to protect remaining bearers. Monitoring must identify the new backing, complete its official conversion, deposit actual permanent sAERO, and deliver the resulting new haiAERO to the appropriate chain before resuming. Blocking an old mint button does not stop old contracts.

Source quotes round down; aggregate reserve requirements round up. One-wei reserve buffers may be needed when v1-to-v2 conversions redistribute rounding between source routes. A caller supplies `minOut`; all source and output balance changes are checked exactly. Fee-on-transfer or rebasing tokens are unsupported. Nonstandard callbacks that add obligations during a transfer fail the post-transfer reserve check.

Surplus output can be withdrawn **only while paused**, **only to the immutable treasury**, and only up to inventory minus all current liabilities. Coverage and exact transfer amounts are checked again afterward. Legacy source tokens can never leave. This lets treasury rebalance new output between chains when old bridge flows shift liability. Pending messages and cross-chain latency can temporarily freeze a destination; there is no atomic cross-chain guarantee.

Do not fund legacy claims using principal from unrelated new public deposits: those deposits mint receipts to their own recipients. Legacy inventory must come from identified migrated legacy backing or explicit treasury contributions. Deposit treasury sAERO directly with the migrator as receipt recipient when appropriate, and bridge the OP reserve using the separately reviewed new route.

## App ABI

`HaiAero`: `BASE_TOKEN`, `BASE_TOKEN_NFT`, `voter`, `deploymentChainId`, `paused`, `treasury`, `principalOf(id)`, `backingOf(id)`, `backingStatus(id)`, `backingTokenIds`, `totalIssuedPrincipal`, `deposit(recipient, amount)`, `depositNFTs(recipient, ids)`.

`Deposited(account indexed, recipient indexed, tokenId indexed, principal)` is emitted once per NFT. New liquid AERO produces one NFT. Only recognized receipt events from the reviewed issuer should confirm an app mint.

`HaiAeroMigrator`: `outputToken`, `deploymentChainId`, `treasury`, `paused`, `sourceTokens`, `routes(source) -> (numerator, denominator, cap, migrated, excludedCustody)`, `outstanding(source)`, `previewMigration(source, amount)`, `readiness() -> (inventory, requiredOutput, capsCoverLiabilities, ready)`, `migrate(source, amount, minOut, recipient) -> outputAmount`.

`Migrated(account indexed, token indexed, recipient indexed, inputAmount, outputAmount)` confirms exchange. Preview does not promise execution: app must check readiness, simulate, approve only the exact input and validate the mined receipt. No execution across a chain switch or changed account should reuse an old quote.

## Validation and deployment preparation

The repository uses exact Solidity 0.8.20. Current Forge normalizes its configured Cancun target to Shanghai for that compiler; the focused commands make this target explicit. The complete unmodified `yarn build` also passes:

```sh
FOUNDRY_FUZZ_RUNS=128 FOUNDRY_FUZZ_SEED=69 forge test --match-path 'test/unit/tokens/HaiAero*.t.sol' --evm-version shanghai
AERO_FORK_RPC=https://mainnet.base.org forge test --match-contract Fork_HaiAero --evm-version shanghai
forge build script/aero/DeployHaiAero.s.sol script/aero/DeployHaiAeroMigrator.s.sol --evm-version shanghai
node script/aero/fork-smoke.mjs
node script/aero/preflight.mjs --manifest script/aero/deployment.example.json --output /tmp/aero-preflight.json
```

The Foundry fork test checks canonical runtimes and constructor bindings. The standalone smoke test starts and destroys a local Anvil Prague fork because upstream Solidity 0.8.36 bytecode uses newer EVM opcodes. It modifies test balances only on loopback, deploys only locally, and tests actual new AERO staking into treasury custody, NFT intake, one-time recognition of Safe-owned migrated NFTs, duplicate rejection, Safe-controlled transfers, and nonempty Base gauge allocation/fee-manager claims directly from the Safe. Production Safe signatures are impersonated only on the local fork. Positive accrued reward payouts and remote-chain transport need a separate rehearsal.

The example preflight manifest intentionally has no HAI deployment addresses and fails closed. Populate each deployment with `address`, `runtimeCodeHash`, `transactionHash`, `blockNumber`, `blockHash` and expected roles. Proxy entries additionally require `implementation: {address, runtimeCodeHash}` and `proxyAdmin`; bridge entries require `owner`, `mailbox`, and `ism`; issuer entries require `owner`, `treasury`, `treasuryOwners`, `treasuryThreshold` and complete current `treasuryTokenIds`; migrators require `owner` and `treasury`. Record a successful direct creation receipt and the exact deployed runtime. Factory deployments require `factoryDeployment: {factory: {address, runtimeCodeHash, implementation?}, eventAbi, addressArgument}` proving the actual child address from a log emitted by the verified factory. Both paths require a successful finalized receipt in the canonical recorded block; factory evidence additionally requires no child code in the preceding block and matching child runtime at creation. Canonical collateral children require their exact creation event, collateral type and token fields. Nonzero EIP-1967 administrator slots always require an explicit matching manifest identity. The app registry aliases `deploymentTransactionHash`, `deploymentBlockNumber`, and `deploymentBlockHash` are also accepted.

Preflight checks finalized creation receipts, current runtime and implementation slots, immutable addresses, role expectations, independent current supply reconciliation, permanent NFT backing, reciprocal new bridge routes and synthetic coverage. It reports `contractsReady` separately from `contractLiveReady`, limited to identity, custody and reserve checks; neither flag approves product activation, collateral/oracles, rewards, liquidity, or cross-chain message reconciliation. Its snapshot is not permission to execute later: run it immediately before activation; contracts repeat local liability checks on-chain. Separately inspect all bridge security-module configuration and administrative powers, reconcile in-flight messages, and approve the governance/operating controls.

Deployment scripts take public configuration via environment variables. They do not read private keys or enable any live feature. `forge script` simulates unless an operator separately adds broadcast and a signer:

- Issuer: `AERO_OWNER`, `AERO_TREASURY`.
- Migrator: `AERO_OUTPUT_TOKEN`, `AERO_OUTPUT_RUNTIME_HASH`, `AERO_OWNER`, `AERO_TREASURY`, `AERO_SOURCE_CAPS` (comma-separated raw token amounts, route order above).
- OP migrator additionally: `AERO_OUTPUT_IMPLEMENTATION`, `AERO_OUTPUT_IMPLEMENTATION_HASH`, `AERO_BRIDGE_ROUTE_REVIEWED`.

Remaining production gates: external contract review; treasury Safe role verification; new Hyperlane route deployment/security review; treasury Safe-approved actual backing migration; receipts/runtime reconciliation; full reserve funding; Safe-approved reward operations and nonempty cross-chain reward rehearsal; new collateral join/auction/governance parameters using the approved existing AERO oracle; debt-safe vault migration; production monitoring. The existing Pyth AERO price reuse is user-approved; no additional feed transition approval is required.

## Unsigned collateral onboarding

`prepare-collateral.mjs` prepares two reviewed governance batches without sending any transaction. The example is intentionally incomplete: choose a distinct collateral type, provide the finalized new OP synthetic deployment identity and the actual execution authority, and explicitly review all risk values in raw WAD/RAY/RAD units. Risk values are not inferred from another collateral. The initial debt ceiling is always zero; the initial tax policy is explicitly primary-only, with no secondary receivers silently copied.

The user-selected `oraclePolicy: "reuse-existing-haiaero-pyth"` uses the existing HAIAERO delayed oracle `0x7DA9D12c5b6Fd2548B0E535Ec12F2406D69aBb75` unchanged. It verifies that the live legacy HAIAERO collateral still points at that exact supplied runtime, and requires a valid positive result. Preparation also verifies current source validity, an update within the existing delay, and two consecutive cache checkpoints no more than the delay plus a documented 300-second scheduling grace apart. One catch-up update after a keeper outage cannot qualify an old current cache. This is a preparation check, not a change to the deployed oracle. This preserves its existing Pyth feed, freshness/confidence rules and delay; it adds no haircut or new feed-transition approval. The underlying Pyth feed is `0x9db37f4d5654aad3e37e2e14ffd8d53265fb3026d1d8f91146539eebaa2ef45f`.

```sh
node --test script/aero/test/*.test.mjs
node script/aero/prepare-collateral.mjs --manifest script/aero/collateral.example.json --phase factories --output /tmp/aero-factories.json
# After separately authorized execution and finality, add actual child receipt/runtime/event evidence to the reviewed manifest.
node script/aero/prepare-collateral.mjs --manifest /path/to/reviewed-collateral.json --phase initialize --output /tmp/aero-initialize.json
node script/aero/collateral-fork-smoke.mjs
```

The first batch calls the canonical join and auction factories. The second requires their actual finalized child addresses and events, checks current bindings/parameters/authorization, and initializes SAFEEngine, OracleRelayer, LiquidationEngine and TaxCollector before updating the price. It rejects existing collateral type collisions and writes a snapshot of legacy collateral parameters into its report. It never emits a legacy parameter modification or a nonzero debt ceiling. A later debt-ceiling increase requires a separate reviewed governance action.

The OP fork rehearsal uses a disposable test token and mirrors current legacy HAIAERO risk parameters solely as integration fixtures. It impersonates the current authorized executor locally and simulates local finality; none of those fixtures are deployment evidence, approved new risk settings or governance signatures. It verifies the actual factory and initialization sequence against current deployed HAI code, unchanged old parameters, same-oracle reuse, zero ceiling and duplicate rejection.

## Recorded validation

The source-only validation record is `script/aero/evidence/validation.json`. Both this change and clean baseline `de5a2d0` pass the exact CI build and lint commands. The exact CI test command gives 1,917 passes / 57 failures / 1 opt-in fork skip here, versus 1,884 passes / 57 failures on baseline. Both runs have the same failing suite/category multiset: 30 legacy `testFail` incompatibilities, 10 existing expected-error mismatches, 15 public RPC availability failures and 2 missing CI signing fixtures. This is not a green full suite; the change adds 33 passing contract tests with no new failing suite. The canonical Base binding fork passes separately.

Twelve script tests and the recorded Base/OP local fork rehearsals pass. The Base reward claim has no accrued payout, and OP smoke finality is locally simulated. These records are test evidence only; they are not production receipts, treasury signatures, deployed collateral or proof of end-to-end reward funding.
