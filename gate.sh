#!/usr/bin/env bash
set -euo pipefail

rm -f src/assets/*.wasm

nix develop -c just lint
nix develop -c just ci

blueprint="$(nix build --quiet --no-link --print-out-paths .#cage-blueprint)"
genesis="$(nix build --quiet --no-link --print-out-paths .#devnet-genesis)"
E2E_GENESIS_DIR="$genesis" nix develop -c just e2e "$blueprint"
