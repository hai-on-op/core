# AutoLiner

See [AutoLiner.sol](/src/contracts/utils/AutoLiner.sol/contract.AutoLiner.html) for the implementation details.

## 1. Purpose

`AutoLiner` maintains the live `SAFEEngine.debtCeiling` for a collateral type so there is always controlled minting headroom above the current debt while respecting:

- a governance-defined ceiling cap
- a minimum live ceiling floor
- a cooldown between any two live ceiling changes

The contract is designed to be an execution utility. Governance configures it, and a keeper or operator calls `updateCeiling(cType)` over time.

## 2. Product Requirements

### Goal

For each initialized collateral type, the live ceiling should follow this rule:

- target ceiling is `min(max(minDebt, currentDebt + gap), ceilingCap)`

Special case:

- if `gap == type(uint256).max`, target ceiling is exactly `ceilingCap`

### Global Params

- `cooldown`: minimum delay between any two live ceiling changes

### Per-Collateral Params

- `ceilingCap`: local ceiling cap for the collateral
- `minDebt`: local minimum live ceiling
- `gap`: local headroom

### Per-Collateral State

- `lastUpdateTime`: timestamp of the last successful live ceiling change

## 3. Source Of Truth

`AutoLiner` uses two distinct sources, with separate responsibilities:

- local `AutoLiner` params are the source of truth for the wanted cap and local tuning
- live collateral configuration in `SAFEEngine` is the currently enforced ceiling

### Before Enabling AutoLiner

Before a collateral is initialized in `AutoLiner`, `SAFEEngine` is both:

- the source of truth for the collateral debt ceiling
- the contract that enforces that ceiling

In that mode, governance only has one relevant ceiling value:

- `SAFEEngine.debtCeiling` is the wanted ceiling
- `SAFEEngine.debtCeiling` is also the live enforced ceiling

### After Enabling AutoLiner

Once a collateral is initialized in `AutoLiner` with a non-zero `ceilingCap`, those responsibilities split:

- `AutoLiner.cParams(cType).ceilingCap` becomes the source of truth for the wanted maximum ceiling
- `SAFEEngine.cParams(cType).debtCeiling` becomes the live enforced ceiling that `AutoLiner` moves over time

This is the key design change introduced by `AutoLiner`:

- before `AutoLiner`, the same storage slot in `SAFEEngine` means both "what governance wants" and "what is currently enforced"
- after `AutoLiner`, governance expresses the wanted cap in `AutoLiner`, while `SAFEEngine` holds the currently applied live ceiling

So when `AutoLiner` is enabled:

- governance should treat `AutoLiner.ceilingCap` as the desired cap
- governance should treat `SAFEEngine.debtCeiling` as the current execution value
- `AutoLiner.updateCeiling(cType)` is the mechanism that reconciles the live SAFEEngine ceiling with the locally configured AutoLiner target

For a collateral type to be managed:

1. it must be initialized in `AutoLiner` through `initializeCollateralType`
2. it must have a non-zero local `ceilingCap` in `AutoLiner`
3. it must have a non-zero live `debtCeiling` in `SAFEEngine`

This creates two separate gates:

- not initialized in `AutoLiner` -> revert `AutoLiner_CollateralTypeNotInitialized`
- initialized in `AutoLiner` but deactivated locally -> revert `AutoLiner_CollateralTypeNotActive`
- initialized in `AutoLiner` but disabled in `SAFEEngine` -> revert `AutoLiner_CollateralTypeNotRegistered`

## 4. Ceiling Cap Resolution

`ceilingCap` is a local AutoLiner control value:

- if local `ceilingCap > 0`, it is the effective cap
- if local `ceilingCap == 0`, the collateral is inactive in `AutoLiner`

Initialization rule:

- `initializeCollateralType` requires `ceilingCap > 0`
- `initializeCollateralType` requires `minDebt > 0`
- `initializeCollateralType` requires `gap > 0`
- after initialization, governance may later set `ceilingCap = 0` through `modifyParameters` to deactivate the collateral in `AutoLiner`

Notice:

- `minDebt` is enforced as a floor at all debt levels
- the target formula is continuous as debt moves to or from zero
- `gap = 0` and `minDebt = 0` are invalid config values

## 5. Operational Procedures

### Onboard A Collateral

1. Initialize the collateral in `SAFEEngine` with a non-zero `debtCeiling`
2. Initialize the collateral in `AutoLiner` with:

```solidity
AutoLinerCollateralParams({
  ceilingCap: <wanted ceiling cap>,
  minDebt: <minimum live ceiling>,
  gap: <headroom>
})
```

3. Authorize `AutoLiner` on `SAFEEngine`
4. Call `updateCeiling(cType)`

Result:

- local `ceilingCap` is the source of truth for the collateral cap
- the resulting target follows the same continuous formula used at all debt levels
- from this point onward, `SAFEEngine.debtCeiling` should be understood as the live enforced ceiling, not the governance source of truth for the desired cap
- if governance later sets `AutoLiner.ceilingCap = 0` for the collateral, `AutoLiner` stops managing that live ceiling and governance must manually set the wanted target directly in `SAFEEngine`

### Change Per-Collateral Params After Onboarding

1. Ensure the collateral was already initialized in `AutoLiner`
2. Call `modifyParameters(cType, param, data)`

Notice:

- changing params does not change the live SAFEEngine ceiling by itself
- setting `ceilingCap = 0` deactivates the collateral in `AutoLiner`
- setting `minDebt = 0` reverts
- setting `gap = 0` reverts
- local deactivation is not the same as live ceiling shutdown:
  setting `ceilingCap = 0` stops future AutoLiner management, but leaves the current live `SAFEEngine.debtCeiling` unchanged
- if governance deactivates AutoLiner locally and also wants a different enforced ceiling, governance must modify `SAFEEngine.debtCeiling` separately

### Disable A Collateral

1. Set `SAFEEngine.debtCeiling = 0`

Result:

- future `updateCeiling(cType)` calls revert with `AutoLiner_CollateralTypeNotRegistered`
- local `AutoLiner` config remains stored
- if local `ceilingCap > 0`, the collateral remains locally active in `AutoLiner`
- execution is blocked because the live `SAFEEngine.debtCeiling` gate is now zero

### Deactivate AutoLiner Locally

1. Set `AutoLiner.ceilingCap = 0` through `modifyParameters`

Result:

- future `getNextDebtCeiling(cType)` and `updateCeiling(cType)` calls revert with `AutoLiner_CollateralTypeNotActive`
- the current live `SAFEEngine.debtCeiling` is not changed by this action
- if governance wants to change the enforced live ceiling after local deactivation, governance must modify `SAFEEngine.debtCeiling` separately

### Restore A Disabled Collateral

1. Set `SAFEEngine.debtCeiling` back to a non-zero value
2. Call `updateCeiling(cType)`

If local `ceilingCap > 0`, it remains the local source of truth.
If local `ceilingCap == 0`, `updateCeiling` continues to revert until governance reactivates the collateral by setting a non-zero cap.

## 6. Keeper Procedure

For each managed collateral type:

1. ensure the collateral is initialized in `AutoLiner`
2. ensure the collateral has a non-zero local `ceilingCap`
3. ensure the collateral has a non-zero live ceiling in `SAFEEngine`
4. if you want only a preview, call `getNextDebtCeiling(cType)`
5. call `updateCeiling(cType)`
6. both `getNextDebtCeiling(cType)` and `updateCeiling(cType)` revert if the live `SAFEEngine.debtCeiling` is zero
7. if the target equals the current live ceiling, the update call is a no-op
8. if the target differs and cooldown has not passed, the update call reverts
9. if the target differs and cooldown has passed, the live ceiling is updated in `SAFEEngine`

## 7. Test Coverage

### Unit Tests

The suite in [test/unit/AutoLiner.t.sol](/test/unit/AutoLiner.t.sol) currently checks:

- constructor validation
- global parameter modification
- rejection of unsupported global params such as `safeEngine`
- mandatory `AutoLiner` initialization before collateral-specific config or execution
- `ceilingCap > 0`, `minDebt > 0`, and `gap > 0` requirements during initialization
- explicit per-collateral initialization storage
- duplicate initialization revert
- local per-collateral parameter modification after initialization
- explicit local deactivation through `ceilingCap = 0`
- rejection of `minDebt = 0` and `gap = 0`
- `minDebt` acting as a floor when `currentDebt + gap` is smaller than `minDebt`
- `gap == type(uint256).max` returning the effective cap
- cooldown enforcement for both increases and decreases
- clamping to `ceilingCap`
- no-op updates preserving `lastUpdateTime`
- distinction between:
  - not initialized in `AutoLiner`
  - initialized in `AutoLiner` but inactive in `AutoLiner`
  - initialized in `AutoLiner` but disabled in `SAFEEngine`

### E2E Tests

The suite in [test/e2e/E2EAutoLiner.t.sol](/test/e2e/E2EAutoLiner.t.sol) currently checks:

- debt generation followed by ceiling reduction to the computed target, including the `minDebt` floor and `ceilingCap` clamp rules
- cooldown blocking intermediate updates
- post-cooldown re-expansion when debt increases
- post-cooldown reduction back to `minDebt` after full repayment
- `gap == type(uint256).max` causing the live ceiling to return directly to the local `ceilingCap`

## 8. Key Invariants

- a collateral must be initialized in `AutoLiner` before it can be managed
- an initialized collateral with `ceilingCap == 0` is inactive in `AutoLiner`
- `minDebt` must never be zero for a valid initialized collateral config
- `gap` must never be zero for a valid initialized collateral config
- a collateral must have non-zero live `SAFEEngine.debtCeiling` to be actively managed
- `lastUpdateTime` only changes when the live ceiling actually changes
- `ceilingCap` is always sourced from local `AutoLiner` params
