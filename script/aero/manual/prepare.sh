#!/usr/bin/env sh
# Public configuration only. These commands compile locally and prepare unsigned data; they send no transaction.
set -eu
cd "$(dirname "$0")/../../.."
output_path=${1:-"/tmp/hai-aero-base-issuer-$(date -u +%Y%m%dT%H%M%SZ).unsigned.json"}
forge build src/contracts/tokens/HaiAero.sol src/contracts/tokens/HaiAeroMigrator.sol --evm-version shanghai
node script/aero/prepare-deployment.mjs \
  --manifest script/aero/deployment.example.json --kind issuer --chain-id 8453 \
  --output "$output_path"
# After the user's deployment, record actual finalized receipt/runtime evidence before preparing migrators:
# node script/aero/prepare-deployment.mjs --manifest /path/to/actual-deployments.json --kind migrator --chain-id 8453 --output /path/to/base-migrator.unsigned.json
# node script/aero/prepare-deployment.mjs --manifest /path/to/actual-deployments.json --kind migrator --chain-id 10 --output /path/to/op-migrator.unsigned.json
# After actual migration settlement, use receipt-derived new NFT IDs and exact principal for the Safe intake package:
# node script/aero/prepare-intake.mjs --manifest /path/to/actual-deployments.json --positions /path/to/actual-migrated-nfts.json --output /path/to/safe-intake.unsigned.json
