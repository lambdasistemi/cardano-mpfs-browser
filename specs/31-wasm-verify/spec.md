# spec — #31 browser verifies via WASM-Haskell (cage reactor), drop the PS/JS crypto re-port

## P1 user story

As an explorer user, I verify a fact/transaction proof in `cardano-mpfs-browser` via
the WASM-compiled Haskell verifier (the `mpfs-cage-reactor`, built on shared `mts`),
and observe the same verdict the producers' `mts` would give — with no PureScript trie
code or JS hash lib in the verification path.

## Context

Today the browser hand-rolls verification: `MPFS/Proof/CSMT.purs` is documented "Port
of the Haskell verification from haskell-mts", `MPFS/Proof/MPF*` likewise, and
`MPFS/Crypto/Hash.purs` hashes via `@noble/hashes` (JS). This is a JS-crypto +
npm-trust-boundary + determinism-drift violation. `mpfs-spa` already does it right:
opaque proofs handed to the WASM cage reactor. The browser flake **already inputs**
`cardano-mpfs-offchain`, which exposes `wasm-mpfs-verify` (`mpfs-cage-reactor.wasm`).

## Functional requirements

- FR1 — the **`mpfs-verify-reactor.wasm`** (the PURE verifier; `verify_ok`/`verify_error`
  contract) from `cardano-mpfs-offchain.packages.*.wasm-mpfs-verify` is bundled as a
  browser asset and loaded/instantiated (port `Reactor.js`). NOT `mpfs-cage-reactor.wasm`
  — that is the tx-building reactor (needs `cage_config`/`eval_context`) and belongs to
  #32 (wallet/submit). Both ship from the same `wasm-mpfs-verify` output
  (`nix/wasm-targets.nix`: `[ mpfs-verify-reactor, mpfs-cage-reactor, cardano-mpfs-cage-tx ]`).
  See epic ruling A-002.
- FR2 — proof verification routes through the reactor (port `runCageReactor` / the
  verify op), replacing `decodeAndVerify` / `MPFS/Proof/*`.
- FR3 — `MPFS/Proof/CSMT.purs`, `MPFS/Proof/MPF*.purs`, `MPFS/Proof/MPF/Merkle.purs`,
  `MPFS/Crypto/Hash.purs` are removed; `@noble/hashes` dropped from `package.json`.
- FR4 — the existing test suite (validated against Haskell `cage-test-vectors`) passes
  through the wasm path.

## Success criteria

- `just ci` green (build + bundle + test) with verification via the wasm reactor.
- No `MPFS/Proof/*` PureScript verifier or `@noble/hashes` remains.
- Verdicts come from `mts:csmt-verify` (via the reactor) — determinism by linkage.

## Non-goals

- Wallet/submit parity (#32); the csmt-utxo second oracle (#33); removing `mpfs-spa` (#372).
- Changing the reactor itself (consume the existing `wasm-mpfs-verify` artifact).
