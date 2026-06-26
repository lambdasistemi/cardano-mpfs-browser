#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
rm -f src/assets/*.wasm
echo "== lint =="; nix develop --quiet --command just lint
echo "== ci (build + bundle + unit) =="; nix develop --quiet --command just ci
echo "== e2e =="
bp=$(nix build --no-link --print-out-paths .#cage-blueprint)
gd=$(nix build --no-link --print-out-paths .#devnet-genesis)
E2E_GENESIS_DIR="$gd" nix develop --quiet --command just e2e "$bp"
echo "GATE GREEN ($(date -Is))"
