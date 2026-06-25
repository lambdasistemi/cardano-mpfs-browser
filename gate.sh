#!/usr/bin/env bash
# Slice gate for PR (#31). Build + bundle + WASM reactor tests
# + purs-tidy lint. Present while in flight; dropped before mark-ready.
set -euo pipefail
cd "$(dirname "$0")"
echo "== lint (purs-tidy) =="
nix develop --quiet --command just lint
echo "== ci (build + bundle + WASM reactor test) =="
rm -f src/assets/*.wasm
nix develop --quiet --command just ci
echo "GATE GREEN ($(date -Is))"
