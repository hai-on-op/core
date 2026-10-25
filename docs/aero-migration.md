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

## Selected legacy reward policy

The user has explicitly chosen to skip legacy historical fee, bribe and rebase cleanup for this migration. The app's operational selection uses `rewardPolicy: "skip"`: historical reward discovery, reward reads, claims and reconciliation are not prerequisites for this selected plan. Other plans retain the default `claim-reviewed` policy. Existing historical evidence remains valid evidence of what was observed; skipping does not mark any balance as zero, claimed, recovered or reconciled.

The official Base and Optimism [`depositVeNFT` implementation](https://github.com/dromos-labs/metadex-public/blob/8b506b450aaa9d4a9f1a77e264f2d9dd508e9ddf/V3/src/migration/Migration.sol#L102-L143) has no legacy reward-claim prerequisite and does not automatically claim fees, bribes or rebases. It converts the current locked principal, unlocks a permanent position if necessary and merges the source NFT before settlement. The verified legacy escrow implementations likewise perform no automatic reward claim in their unlock, merge or burn paths; merging burns the old NFT. Unclaimed rebases are not added to migrated principal, and skipped claims may become inaccessible after the burn. Migration ownership, current principal, eligibility, vote reset, approval, native transport-fee and source-to-destination settlement checks still apply.

This decision applies to legacy cleanup only. Reward collection, accounting, funding and distribution for holders of the new product remain separate implementation and activation work; prior zero-accrual fork claims do not establish that future reward flow.

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

Remaining production work: review through the existing release/governance process; treasury Safe role verification; new Hyperlane route deployment and configuration review; actual backing migration through the treasury Safe; receipts/runtime reconciliation; full reserve funding; new-product holder reward operations and a nonempty cross-chain reward rehearsal; new collateral join/auction/governance parameters using the selected existing AERO oracle; a documented borrower repayment/withdrawal/redeposit path; production monitoring. Legacy historical reward cleanup is intentionally skipped under the selected policy above and is not a migration prerequisite. The existing Pyth AERO price reuse is selected; no additional feed transition approval is required. A flash-funded vault migration helper is not a prerequisite of this implementation and is not provided here.

## Unsigned collateral onboarding

`prepare-collateral.mjs` prepares two reviewed governance batches without sending any transaction. The example is intentionally incomplete: choose a distinct collateral type, provide the finalized new OP synthetic deployment identity and the actual execution authority, and explicitly review all risk values in raw WAD/RAY/RAD units. Risk values are not inferred from another collateral. The initial debt ceiling is always zero; the initial tax policy is explicitly primary-only, with no secondary receivers silently copied.

The user-selected `oraclePolicy: "reuse-existing-haiaero-pyth"` uses the existing HAIAERO delayed oracle `0x7DA9D12c5b6Fd2548B0E535Ec12F2406D69aBb75` unchanged. It verifies that the live legacy HAIAERO collateral still points at that exact supplied runtime, and requires a valid positive result. Preparation also verifies current source validity, an update within the existing delay, and two consecutive cache checkpoints no more than the delay plus a documented 300-second scheduling grace apart. One catch-up update after a keeper outage cannot qualify an old current cache. This is a preparation check, not a change to the deployed oracle. This preserves its existing Pyth feed, staleness and sequencer checks, and delay; it adds no haircut or new feed-transition approval. The underlying Pyth feed is `0x9db37f4d5654aad3e37e2e14ffd8d53265fb3026d1d8f91146539eebaa2ef45f`.

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

Twenty-two script tests and the recorded Base/OP local fork rehearsals pass. The Base reward claim has no accrued payout, and OP smoke finality is locally simulated. These records are test evidence only; they are not production receipts, treasury signatures, deployed collateral or proof of end-to-end reward funding.

## Manual deployment and final treasury intake

The user will deploy these contracts themselves. `script/aero/manual/base-issuer.unsigned.json` contains the exact Base issuer creation payload and constructor encoding for confirmed deployer `0xbd8EC4cb226EBaE228F8829E2ec23070b09165d3`, with both owner and immutable treasury set to Safe `0x7F4735237c41F7F8578A9C7d10A11e3BCFa3D4A3`. It records the reviewed contract source commit, initcode hash, compiler settings, every source hash, canonical upstream runtime/bindings and observed Safe controls. It is unsigned and records no deployed address. Nonce and transaction fee settings remain with the user's wallet.

`prepare-deployment.mjs` checks constructor ABI, tested creation-bytecode hash and metadata against `artifacts-reviewed.json`; it rejects stale source files and linked libraries. Optional read-only gas estimation and deployer balance checks report whether observed balance covers estimated execution cost, separately from L1 data/operator fees. Lack of funding or an unavailable gas estimate does not prevent preparing the package. Gas and balance observations must be refreshed before the user's later execution.

```sh
sh script/aero/manual/prepare.sh
node script/aero/prepare-deployment.mjs --manifest /path/to/actual-deployments.json --kind migrator --chain-id 8453 --output /tmp/base-migrator.unsigned.json
node script/aero/prepare-deployment.mjs --manifest /path/to/actual-deployments.json --kind migrator --chain-id 10 --output /tmp/op-migrator.unsigned.json
```

Migrator preparation requires actual finalized output-token receipts/runtime and explicit source caps. Base output must prove the exact reviewed issuer creation payload from the confirmed deployer. OP output additionally requires recorded route review and full proxy identity evidence. A predicted token address cannot satisfy either path. Preparation emits no transaction-sending command; `manual/prepare.sh` only builds and generates unsigned data.

After official migration has actually settled, `prepare-intake.mjs` consumes the deployed issuer manifest and an explicit selection shaped like `intake.example.json`. Each position must have the actual new sAERO ID, exact principal and finalized canonical Base transaction/block evidence. Base positions bind to `VeNFTMigrated` and their old token ID; OP positions bind to the destination `Migrated` nonce, used-nonce state, and minted-and-transferred NFT in that event's log segment. The tool verifies actual Safe ownership, unchanged principal and an unused issuer `principalOf` entry. It never substitutes a predicted NFT ID.

```sh
node script/aero/prepare-intake.mjs --manifest /path/to/actual-deployments.json --positions /path/to/actual-migrated-nfts.json --output /tmp/safe-intake.unsigned.json
node script/aero/intake-fork-smoke.mjs
```

The generated Safe Transaction Builder batch calls the verified `upgradeToPermanentStake(id)` for each finite new sAERO position. This preserves principal and internally re-anchors the Voter; conversion itself needs no reset/deallocation. An expired funded position first uses verified `increaseStakingPeriod(id, 1)` to renew it to the next week boundary, then converts permanently. Previously existing leaf allocations may need their normal voting refresh separately. Legacy veNFT vote reset and all principal/ownership/settlement checks before official migration still apply; historical reward claims are intentionally skipped under the selected policy.

The final call is `depositNFTs(recipient, actualIds)`, authenticated by Safe ownership, with receipts sent to the Safe or an explicitly verified Base migrator. No NFT approval or same-owner transfer is needed. If the issuer is paused, the batch temporarily unpauses and restores pause around intake. Execute the entire ordered Safe batch atomically and refresh evidence before signing. This creates receipts against the selected actual principal; it does not activate migrators, bridge inventory or enable borrowing.

The supplemental fork test migrates actual finite legacy Base NFT `8814` on a disposable pinned fork, derives its new ID from the genuine settlement, converts it permanently, registers exact principal to the Safe, restores pause and rejects duplicate intake. Production assets and signatures are never used by the test.

Remote CI for PR160 at `fbbfa5c` remains **failing**: [run 40123603899](https://github.com/hai-on-op/core/actions/runs/40123603899) reports 1,952 passes and 113 failures. All 33 new issuer/migrator tests pass. Failures comprise 79 legacy `testFail` methods (nightly lists these individually), 10 existing expected-error mismatches and 24 fork initializations blocked by the configured OP RPC hostname failing DNS. All failing tests belong to 39 files unchanged from baseline; all legacy failure names were checked against baseline. This remote result is separate from the local 57-failure comparison.

Before OP-origin intake, run the app's [source-to-destination settlement verifier](https://github.com/hai-on-op/app/blob/c2c0bd2eff1b5ba924526ea8b964da1fbcacc0b8/scripts/aero-migration/verify-settlement.cjs). It binds old OP NFT migration, dispatch nonce and Base destination settlement. The core intake generator verifies the actual Base nonce settlement, Safe recipient, principal and new NFT, while `positionsReviewed` records the separately reconciled product provenance; it does not replace that OP source-chain check.

The optional `intake-fork-smoke.mjs --expired` rehearsal remains unverified: after advancing years beyond the actual migrated stake expiry, Anvil advanced the sending account nonce but returned no transaction receipt. Active finite intake passed its six checks. The expired-renewal call encoding has unit coverage and matches the verified upstream implementation, but its full fork lifecycle still needs a successful rehearsal before using that path. No production transaction was attempted.
