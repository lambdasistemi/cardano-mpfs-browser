# Issue #49: Per-Fact MPF Inclusion Verify

## P1 User Story

As an MPFS user, when I look up a fact for the selected token, the browser
anchors the fact response snapshot against the independent UTxO-CSMT oracle,
forwards the raw `/tokens/:id/facts/:key` proof response to the bundled Haskell
WASM verifier, and shows `Verified` only when the verifier returns `verify_ok`.
If the proof, key, or independently anchored root check is tampered, the app
shows rejected.

## Context

This is the first DELEGATION child of epic #47. The browser must not decode,
reassemble, or independently verify the MPF proof in PureScript. The server
already returns the read-side proof shape:

```json
{"fact":{"mpf_proof":"...","state":{...}},"snapshot":{...},"value":"..."}
```

`cardano-mpfs-offchain#380` adds `verify_fact_inclusion` to the
`mpfs-verify-reactor.wasm` package. The browser's job is to repin that input,
preserve the raw fact response as JSON, independently anchor the response
snapshot root, and call `MPFS.Reactor.verifyEnvelope` with:

```json
{
  "op": "verify_fact_inclusion",
  "trusted_root": "<independent UTxO-CSMT root at facts.snapshot.chainpoint.slot>",
  "facts": "<raw /facts/:key response object>",
  "key": "<fact key hex>"
}
```

The `trusted_root` is the UTxO-CSMT root for the fact response snapshot, not the
selected token facts root. It must be fetched independently through the existing
second-oracle client, matched by `facts.snapshot.chainpoint.slot`, and checked
for equality with the raw response's `snapshot.utxo_root` before the verifier
result can be trusted.

## Functional Requirements

- FR-001: `flake.lock` pins `cardano-mpfs-offchain` to
  `82dc3b93c08374b068f3351a85e5e7311474728e` and only updates the offchain
  input plus its follows.
- FR-002: The fact lookup client can return the raw parsed JSON response while
  preserving the existing looked-up value.
- FR-003: Lookup reads the raw fact response's snapshot slot, fetches the
  independently served UTxO-CSMT roots through `MPFS.SecondOracle.Client`, and
  requires the root at that slot to equal the raw response's
  `snapshot.utxo_root`.
- FR-004: Lookup builds the `verify_fact_inclusion` envelope with the
  independently anchored UTxO-CSMT root, the raw response object, and the lookup
  key hex.
- FR-005: Lookup immediately calls `MPFS.Reactor.verifyEnvelope`; `verify_ok`
  maps to the existing `Verified` UI state, while `verify_error: ...` or an
  anchoring mismatch maps to a rejected/failed UI state with the verifier or
  anchoring message.
- FR-006: The UI no longer requires a manual proof-envelope paste for looked-up
  facts. Manual envelope verification may remain available only if it does not
  obscure the automatic lookup verdict.
- FR-007: Tests use a captured real `umpfs.plutimus.com` `/facts/:key` response
  with a non-empty `mpf_proof`; the original response verifies and a tampered
  proof rejects through the real bundled reactor.
- FR-008: Tests prove an independent-root mismatch fails as not anchored before
  the app can report a trusted verifier success.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- `flake.lock` shows the offchain input at `82dc3b9...` and no unrelated input
  bumps.
- A captured live `GET /tokens/:id/facts/:key` fixture verifies through
  `verify_fact_inclusion` after the fixture snapshot root is independently
  anchored against the second-oracle root at the same slot.
- A tampered version of that same fixture returns `verify_error`.
- A mismatched independent UTxO-CSMT root produces a rejected/not-anchored
  outcome.
- Looking up a real fact in the running app shows `Verified` automatically.
- No PureScript proof reimplementation is introduced.
- The PR links `Closes #49` and parent `#47`.

## Non-Goals

- Do not edit `src/MPFS/Reactor.purs`, its JavaScript FFI, or the Haskell
  offchain repository.
- Do not implement MPF proof decoding, proof traversal, hash checking, or
  verifier semantics in PureScript.
- Do not replace the read-side server API.
- Do not make live `umpfs.plutimus.com` availability the only CI proof; use a
  captured real fixture for CI and leave the final live browser walk to the
  epic owner.
