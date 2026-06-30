#!/usr/bin/env bash
set -euo pipefail

rm -f src/assets/*.wasm

nix develop --quiet --command just lint
nix develop --quiet --command just ci

bp="$(nix build --fallback --quiet --no-link --print-out-paths .#cage-blueprint)"
gd="$(nix build --fallback --quiet --no-link --print-out-paths .#devnet-genesis)"
E2E_GENESIS_DIR="$gd" nix develop --quiet --command just e2e "$bp"
