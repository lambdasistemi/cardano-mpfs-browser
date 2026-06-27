#!/usr/bin/env bash
set -euo pipefail

rm -f src/assets/*.wasm

nix develop --quiet -c just lint
nix develop --quiet -c just ci

blueprint="$(nix build --quiet --no-link --print-out-paths .#cage-blueprint)"
genesis="$(nix build --quiet --no-link --print-out-paths .#devnet-genesis)"

E2E_GENESIS_DIR="$genesis" nix develop --quiet -c just e2e "$blueprint"
