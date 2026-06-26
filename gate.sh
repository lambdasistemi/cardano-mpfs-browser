#!/usr/bin/env bash
# Gate for #36 (/tokens decoder). Mirrors CI: lint + ci(build+bundle+unit) + e2e.
# Includes the #31 clean-asset hardening so prepare-wasm's idempotent path is tested.
set -euo pipefail
cd "$(dirname "$0")"
rm -f src/assets/*.wasm
echo "== lint (purs-tidy) =="
nix develop --quiet --command just lint
echo "== ci (build + bundle + unit, 17/17) =="
nix develop --quiet --command just ci
echo "== e2e (the /tokens proof) — mirrors CI =="
bp=$(nix build --no-link --print-out-paths .#cage-blueprint)
gd=$(nix build --no-link --print-out-paths .#devnet-genesis)
E2E_GENESIS_DIR="$gd" nix develop --quiet --command just e2e "$bp"
echo "GATE GREEN ($(date -Is))"
