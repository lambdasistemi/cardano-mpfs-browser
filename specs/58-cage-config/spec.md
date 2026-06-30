# Issue #58: Substitute Cage Config From Blueprint

## P1 User Story

As an MPFS user, when the browser verifies token-list completeness or pending
requests against live `umpfs.plutimus.com`, the verifier receives the real cage
script bytes, request script bytes, and cage policy hash. The browser must not
ship the `__MPFS_...` placeholders that make the Haskell reactor reject the
envelope as invalid hex.

## Context

This is a DELEGATION child of epic #47. Issues #50 and #52 already build the
correct `verify_tokens` and `verify_snapshot` envelopes, including
`MPFS.App.Config.defaultCageConfig`. The live walk showed those two paths fail
only because the default cage config still contains build-time placeholders in
`dist/index.js`.

The deterministic source of truth is the bundled on-chain cage blueprint:

```sh
nix build --fallback --no-link --print-out-paths .#cage-blueprint
```

The produced `plutus.json` contains:

- `state.state.mint.compiledCode` -> `cageScriptBytes`
- `state.state.mint.hash` -> `cfgScriptHash`
- `request.request.spend.compiledCode` -> `requestScriptBytes`

The live walk verified `state.state.mint.hash` equals the live UMPFS cage
policy `ad0a8eeeec8b0a5ee9930be5d6ea2e80b285fc2f3e9675a13a392dd5`.

## Functional Requirements

- FR-001: The browser bundle substitutes all `__MPFS_...` cage-config
  placeholders with values read from `.#cage-blueprint`.
- FR-002: The substitution fails loudly if any required validator title is
  missing, if a required blueprint field is absent, or if any substituted value
  is not valid lowercase or uppercase hex.
- FR-003: The bundled `dist/index.js` contains no `__MPFS_` placeholder after
  `just bundle` or `just ci`.
- FR-004: A regression test derives the expected values from the same blueprint
  and proves the bundled cage config is valid hex and not a placeholder.
- FR-005: The PureScript verification and write-flow wiring stay unchanged; the
  bug is the default config shipped to those paths.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- `just bundle` produces `dist/index.js` with no `__MPFS_` placeholders.
- The bundled `cageScriptBytes`, `requestScriptBytes`, and `cfgScriptHash` are
  valid hex strings derived from `.#cage-blueprint`.
- `cfgScriptHash` in the bundle is
  `ad0a8eeeec8b0a5ee9930be5d6ea2e80b285fc2f3e9675a13a392dd5` for the current
  flake lock.
- The PR links `Closes #58` and parent `#47`.

## Non-Goals

- Do not change the `verify_tokens` or `verify_snapshot` envelope wiring from
  issues #50 and #52.
- Do not edit the offchain or onchain repositories.
- Do not fetch cage config from a live backend at runtime for this ticket; the
  bundled blueprint is the deterministic source.
