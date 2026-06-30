# Issue #51: Full Facts-Set Verify

## P1 User Story

As an MPFS user, when I load the Facts tab for a token, the browser anchors the
raw `GET /tokens/:id/facts` snapshot against the independent UTxO-CSMT oracle,
forwards the unchanged facts response to the bundled Haskell WASM verifier, and
shows `Facts set: Verified` only when the verifier returns `verify_ok`. If any
fact or proof data in the set is tampered, the app shows rejected.

## Context

This is a DELEGATION child of epic #47. The browser must not implement
whole-facts-set verification in PureScript. `cardano-mpfs-offchain#380`
provides the read-side verifier op in the already repinned
`mpfs-verify-reactor.wasm`; this ticket wires the browser to that op.

The verifier envelope is:

```json
{
  "op": "verify_facts",
  "trusted_root": "<independent UTxO-CSMT root at facts.snapshot.chainpoint.slot>",
  "facts": "<raw /tokens/:id/facts response object>"
}
```

If the reactor contract requires the browser cage configuration for this op,
the envelope may also include the same `cage_config` object used by issue #50.

The trusted root is not taken on trust from `/tokens/:id/facts`. The browser
reads `snapshot.chainpoint.slot`, fetches independent UTxO-CSMT merkle roots
through `MPFS.SecondOracle.Client.getMerkleRoots`, requires the matching slot
root to equal `snapshot.utxo_root`, and passes that independent root to the WASM
op.

## Functional Requirements

- FR-001: The client can fetch `GET /tokens/:id/facts` as raw parsed JSON while
  preserving the existing decoded `Array FactEntry` for app state.
- FR-002: Facts loading reads the raw response snapshot slot, fetches the
  independent UTxO-CSMT roots, and rejects the facts-set verdict if no matching
  root exists or if it does not equal `snapshot.utxo_root`.
- FR-003: Facts loading builds a `verify_facts` envelope with the independent
  trusted root and raw `/tokens/:id/facts` response.
- FR-004: Facts loading calls `MPFS.Reactor.verifyEnvelope`; `verify_ok` maps to
  `Verified`, while `verify_error` or anchoring errors map to rejected with the
  verifier or anchoring message available in state/UI.
- FR-005: The Facts tab displays a `Facts set: Verified` / rejected indicator
  distinct from the existing per-fact lookup verifier and the second-oracle
  indicator.
- FR-006: Tests use a captured real `umpfs.plutimus.com`
  `/tokens/:id/facts` response with a non-empty `facts` array; the honest
  response verifies and a tampered response rejects through the real bundled
  reactor.
- FR-007: Tests prove that a mismatched independent UTxO-CSMT root fails before
  the app can report `Verified`.
- FR-008: No PureScript facts-set proof traversal, hash semantics, or MPF/CSMT
  verification implementation is introduced.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- A captured real non-empty `GET /tokens/:id/facts` fixture verifies through
  `verify_facts` after independent UTxO-CSMT root anchoring.
- A tampered version of that same fixture returns `verify_error`.
- A mismatched independent UTxO-CSMT root produces a rejected/not-anchored
  outcome.
- Loading facts in the running app shows `Facts set: Verified` for the live
  positive path and rejected for the walked negative/tampered path.
- The PR links `Closes #51` and parent `#47`.

## Non-Goals

- Do not edit `src/MPFS/Reactor.purs`, `src/MPFS/Reactor.js`, the Haskell
  offchain repository, or `flake.lock`.
- Do not decode, reassemble, or verify the facts-set proof in PureScript.
- Do not make empty fixtures the proof; CI must exercise real non-empty captured
  data, with live walking left to the epic owner.
