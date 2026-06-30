# Issue #50: Token List Completeness Verify

## P1 User Story

As an MPFS user, when I load the token registry, the browser anchors the raw
`GET /tokens` snapshot against the independent UTxO-CSMT oracle, forwards the
unchanged response to the bundled Haskell WASM verifier, and shows `complete`
only when the verifier returns `verify_ok`. If the token list or
`completeness_proof` is tampered, the app shows incomplete.

## Context

This is a DELEGATION child of epic #47. The browser must not implement token
set completeness verification in PureScript. `cardano-mpfs-offchain#380`
provides the read-side verifier op in the already repinned
`mpfs-verify-reactor.wasm`; this ticket wires the browser to that op.

The verifier envelope is:

```json
{
  "op": "verify_tokens",
  "trusted_root": "<independent UTxO-CSMT root at tokens.snapshot.chainpoint.slot>",
  "facts": "<raw /tokens response object>",
  "cage_config": "<browser cage config>"
}
```

The trusted root is not taken on trust from `/tokens`. The browser reads
`snapshot.chainpoint.slot`, fetches independent UTxO-CSMT merkle roots through
`MPFS.SecondOracle.Client.getMerkleRoots`, requires the matching slot root to
equal `snapshot.utxo_root`, and passes that independent root to the WASM op.

## Functional Requirements

- FR-001: The client can fetch `GET /tokens` as raw parsed JSON while preserving
  the existing decoded token-id list for app state.
- FR-002: Token loading reads the raw response snapshot slot, fetches the
  independent UTxO-CSMT roots, and rejects the load as incomplete if no matching
  root exists or if it does not equal `snapshot.utxo_root`.
- FR-003: Token loading builds a `verify_tokens` envelope with the independent
  trusted root, raw `/tokens` response, and `MPFS.App.Config.defaultCageConfig`.
- FR-004: Token loading calls `MPFS.Reactor.verifyEnvelope`; `verify_ok` maps to
  `complete`, while `verify_error` or anchoring errors map to `incomplete` with
  the verifier or anchoring message available in state/UI.
- FR-005: The Tokens tab displays a `Token list: complete` / `incomplete`
  indicator alongside the existing token loading status.
- FR-006: Tests use a captured real `umpfs.plutimus.com` `/tokens` response
  with non-empty entries and a real `completeness_proof`; the honest response
  verifies and a tampered response rejects through the real bundled reactor.
- FR-007: Tests prove that a mismatched independent UTxO-CSMT root fails before
  the app can report `complete`.
- FR-008: No PureScript completeness proof implementation, proof traversal, or
  hash semantics are introduced.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- A captured real non-empty `GET /tokens` fixture verifies through
  `verify_tokens` after independent UTxO-CSMT root anchoring.
- A tampered version of that same fixture returns `verify_error`.
- A mismatched independent UTxO-CSMT root produces an incomplete/not-anchored
  outcome.
- Loading tokens in the running app shows `Token list: complete` for the live
  positive path and `incomplete` for the walked negative/tampered path.
- The PR links `Closes #50` and parent `#47`.

## Non-Goals

- Do not edit `src/MPFS/Reactor.purs`, `src/MPFS/Reactor.js`, the Haskell
  offchain repository, or `flake.lock`.
- Do not decode, reassemble, or verify the token-set completeness proof in
  PureScript.
- Do not make empty fixtures the only proof; CI must exercise real non-empty
  captured data, with live walking left to the epic owner.
