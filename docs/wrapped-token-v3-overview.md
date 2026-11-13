# haiAEROV2 migration

We're moving the existing haiVELO and haiAERO into haiAEROV2. The setup should work much like WrappedTokenV2: users deposit the underlying into the treasury and get their wrapped tokens right away. We manage the backing afterward.

The new contract is `WrappedTokenV3.sol`. The token name is `haiAEROV2` and the symbol is `haiAERO`, matching how we named haiVELOV2. It has 18 decimals. The permit signature domain also uses `haiAEROV2`.

We need one instance of the contract on Base and one on OP:

| Chain | What users can do |
| --- | --- |
| Base | Deposit AERO or sAERO NFTs to mint haiAERO |
| OP | Deposit xAERO to mint haiAERO, or migrate their existing haiVELO/haiAERO |

Both use the same contract code. Hyperlane connects them so users can move their haiAERO between chains.

V3 hasn't been deployed. The contract and local tests are in this branch. We still need to finish the app integration and prepare the deployment steps for this version. The older deployment files were prepared for a different design and shouldn't be used to deploy V3.

## Depositing AERO and xAERO

On Base, a user deposits AERO. On OP, they deposit xAERO. In both cases, `deposit(recipient, amount)` sends the tokens straight to that chain's treasury and mints the same amount of haiAERO to the recipient.

So if someone deposits 100 xAERO on OP, they get 100 haiAERO on OP immediately. They don't have to wait for us to move or stake the underlying.

We then redeem the xAERO for AERO on Base and stake it ourselves. Aero's xAERO redemption is 1:1 in token units, but it takes time to settle and has transport fees and route limits. We need to account for those when moving the backing.

The OP token is listed in Aero's [Optimism deployment file](https://github.com/dromos-labs/metadex-public/blob/2ce1816b20948c26a2eec52419c9eccac3857136/deployment-addresses/leaf-optimism.json), and the redemption function is in [ILeafVoter](https://github.com/dromos-labs/metadex-public/blob/2ce1816b20948c26a2eec52419c9eccac3857136/V3/src/interfaces/voter/ILeafVoter.sol). The earlier check of the token, voter and bridge route was at finalized OP block `159492445`. We'll need to check the route again before using it.

The wrapper checks that the treasury receives the full deposit amount. A transfer that takes a fee out of that amount will revert.

## Depositing sAERO NFTs

Users can also deposit their sAERO NFTs on Base through `depositNFTs(recipient, tokenIds)`. The NFT goes to the treasury and the user gets haiAERO based on how much AERO is in it, using `staked(tokenId).amount`.

An NFT containing 100 AERO mints 100 haiAERO. Timed and permanent positions both work. We don't change the staking terms or filter NFTs based on their end date.

Each NFT needs a positive balance. The contract rejects duplicate IDs in the same batch, like V2. It doesn't keep a lifetime record of deposited IDs, so an NFT returned by the treasury can be deposited again and mint against its current balance.

The contract transfers each NFT, checks that the treasury owns it and that its balance hasn't changed, then mints the haiAERO. The configured treasury itself cannot call the deposit functions to mint against assets it already holds.

We still control the backing NFTs through the treasury. That also means we're responsible for keeping the backing lined up with the haiAERO we've issued. Moving backing, redeeming xAERO, staking AERO or migrating old backing doesn't mean we should mint another set of haiAERO against it. The contract doesn't fully enforce that accounting for us, including when we return an NFT that can then be deposited again.

Until we stake the deposits, some backing will be liquid AERO or xAERO. Holding haiAERO doesn't mean all of its backing is already permanently staked or earning staking rewards.

## Migrating existing haiVELO and haiAERO

All holder conversions happen on OP, inside V3.

| Existing token on OP | haiAEROV2 received per token |
| --- | ---: |
| haiVELO v1 | 0.044 |
| haiVELO v2 | 0.044 |
| haiAERO v1 | 1 |

For example, 1,000 haiVELO converts to 44 haiAERO. 1,000 old haiAERO converts to 1,000 new haiAERO.

`migrate(source, amount, minOut, recipient)` sends the old tokens to `0x000000000000000000000000000000000000dEaD`, checks that the full amount arrived, and mints the new tokens directly. This follows the old V1-to-V2 migration pattern. We don't need to stock the contract with replacement tokens first or use a separate migrator.

The source addresses and rates are fixed in the contract. Conversion rounds down to the smallest token unit and rejects an output of zero. `previewMigration` gives the expected amount, and `minOut` lets the caller set the minimum they'll accept. Once the old tokens are sent to the dead address, they can't be used in another migration, including the old haiVELO V1-to-V2 conversion.

Anyone holding old haiAERO on Base needs to use the existing bridge to move it to OP first, then migrate there. Vault collateral and debt don't move automatically through this function. Historical reward cleanup is outside this work.

Before opening migration, we need to check that the migrated backing covers the existing haiVELO and haiAERO, and plan for any deposits that still arrive through the legacy contracts. V3 doesn't calculate all liabilities across chains or add per-token migration caps. Treasury movements and new minting need to stay coordinated.

## Bridging the new haiAERO

Both contracts use Hyperlane's `HypERC20`. Calling `transferRemote` burns haiAERO on the source chain. Once the destination accepts the message from the configured counterpart, it mints the same amount there.

Using the earlier example, someone deposits 100 xAERO on OP and gets 100 haiAERO. If they bridge 40 haiAERO to Base, they end up with 60 on OP and 40 on Base after the message arrives. The 100 xAERO is still in our OP treasury until we redeem it. Redeeming and staking that backing doesn't change their haiAERO balances.

We need to count pending bridge messages when comparing supply and backing, because those tokens have been burned on one chain but haven't been minted on the other yet.

We'll connect the two new V3 token addresses directly to each other. Old haiAERO holders on Base will use the existing bridge to move to OP before migrating. We shouldn't connect either new token to the old collateral router or the earlier proposed Base escrow route; this version uses burn/mint on both sides.

## Authorization and treasury management

V3 uses the same `Authorizable` and `Modifiable` contracts as the rest of the protocol. The deployer starts authorized. Authorized accounts can add or remove authorization, pause or unpause, and change the deposit manager.

We change the deposit manager with:

```solidity
modifyParameters('baseTokenManager', abi.encode(newManager))
```

That changes where future deposits go. It doesn't move assets out of the previous treasury or change either address's authorization. A deposit uses the manager selected at the start of the call, even if an authorized callback changes the setting during that transaction.

The initial manager can be a Safe, another contract or an ordinary wallet. It can't be zero or the wrapper itself. Later updates use V2's nonzero-address check. A contract receiving NFTs needs to support ERC721 receipt.

Both instances start paused. Pausing stops token deposits, NFT deposits and migration together. Transfers, permit approvals and bridging keep working.

Hyperlane still has its own owner for bridge settings: counterpart addresses, security checks, hooks, gas and optional fees. That role is separate from protocol authorization. Being the treasury or bridge owner doesn't automatically make an account authorized in V3, so we need to set up the intended admins and remove deployment-only access on each chain. These are trusted roles, especially because changing bridge verification can affect who can trigger minting.

There is no unrestricted external `mint()` or recovery function. Permit approvals are already implemented using OpenZeppelin's signature components and Hyperlane's existing token balances and allowances. Signatures are tied to the chain and contract address.

## Deployment settings

We'll deploy V3 directly, like V2. It starts with zero supply, initializes in the constructor and disables further initialization. There's no proxy or code-upgrade function.

The constructor takes `IWrappedTokenV3.DeploymentConfig`. It checks the deployment chain, mailbox domain, underlying token decimals and, on Base, that the NFT contract's `TOKEN()` matches the AERO address.

| Setting | Base | OP |
| --- | --- | --- |
| `chainId` | 8453 | 10 |
| `baseToken` | AERO `0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee` | xAERO `0xbdEaeA5205d16f34Cb40038052d91235D87B4C54` |
| `baseTokenNFT` | sAERO `0xBF7977E1521e9a3032bf7243Ee4712f311f13915` | Zero address |
| `treasury` | Existing Base Safe | Existing OP Safe |
| `mailbox`, `hook`, `interchainSecurityModule` | Base bridge settings to verify before deployment | OP bridge settings to verify before deployment |
| `bridgeOwner` | Existing bridge administrator | Existing bridge administrator |

The treasury address we've been using is `0x7F4735237c41F7F8578A9C7d10A11e3BCFa3D4A3` on both chains. The bridge administrator is `0xbd8EC4cb226EBaE228F8829E2ec23070b09165d3`. We'll verify those addresses and the current bridge configuration when preparing deployment. The constructor checks don't tell us whether we've selected the right backing token. We still need to verify the token address and what backs it.

After deployment, we need to enroll OP domain `10` on the Base instance and Base domain `8453` on the OP instance, configure gas and security, test both directions, and then unpause when the backing and migration are ready.

## Build and testing

Hyperlane is installed through Yarn as `@hyperlane-xyz/core` version `12.2.0`. Its bundled OpenZeppelin dependencies are version `4.9.3`. The scoped remappings let Hyperlane use those while the rest of HAI keeps using OpenZeppelin `5.0.1`.

We're using Solidity `0.8.20` with the Shanghai target and keeping the protocol's 10,000 optimizer runs. V3 uses `via_ir` so it fits the 24,576-byte deployment limit. That setting applies specifically to V3; the default settings for the rest of the protocol stay the same. Foundry applies it automatically, and we'll use Solidity `0.8.20`, Shanghai, `via_ir = true`, and 10,000 optimizer runs for both deployment and verification.

When we verify V3 on the explorer with `forge verify-contract`, we'll use `--compilation-profile wrapped_token_v3 --evm-version shanghai` to match the build.

```sh
yarn install --frozen-lockfile
forge build src/contracts/tokens/WrappedTokenV3.sol --evm-version shanghai
FOUNDRY_FUZZ_RUNS=128 FOUNDRY_FUZZ_SEED=69 forge test --match-path 'test/unit/tokens/WrappedTokenV3.t.sol' --evm-version shanghai
```

The local tests cover deposits, NFT custody, migration, authorization, signatures and supply across the two instances. They use a mock mailbox. We still need a live rehearsal for bridge verification and delivery, xAERO redemption, route availability and collateral onboarding before we call the migration ready to ship.
