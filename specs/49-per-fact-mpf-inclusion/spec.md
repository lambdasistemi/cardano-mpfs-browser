# Issue #49: Per-Fact MPF Inclusion Verify

## P1 User Story

As an MPFS user, when I look up a fact for the selected token, the browser
forwards the raw `/tokens/:id/facts/:key` proof response to the bundled Haskell
WASM verifier and shows `Verified` only when the verifier returns `verify_ok`.
If the proof, key, or trusted facts root is tampered, the app shows rejected.

## Context

This is the first DELEGATION child of epic #47. The browser must not decode,
reassemble, or independently verify the MPF proof in PureScript. The server
already returns the read-side proof shape:

```json
{"fact":{"mpf_proof":"...","state":{...}},"snapshot":{...},"value":"..."}
```

`cardano-mpfs-offchain#380` adds `verify_fact_inclusion` to the
`mpfs-verify-reactor.wasm` package. The browser's job is to repin that input,
preserve the raw fact response as JSON, and call `MPFS.Reactor.verifyEnvelope`
with:

```json
{
  "op": "verify_fact_inclusion",
  "trusted_root": "<selected token facts root>",
  "facts": "<raw /facts/:key response object>",
  "key": "<fact key hex>"
}
```

The selected token facts root is the root from `GET /tokens/:id`, not the
global UTxO root from `/status`.

## Functional Requirements

- FR-001: `flake.lock` pins `cardano-mpfs-offchain` to
  `82dc3b93c08374b068f3351a85e5e7311474728e` and only updates the offchain
  input plus its follows.
- FR-002: The fact lookup client can return the raw parsed JSON response while
  preserving the existing looked-up value.
- FR-003: Lookup builds the `verify_fact_inclusion` envelope with the selected
  token's current facts root, the raw response object, and the lookup key hex.
- FR-004: Lookup immediately calls `MPFS.Reactor.verifyEnvelope`; `verify_ok`
  maps to the existing `Verified` UI state, while `verify_error: ...` maps to a
  rejected/failed UI state with the verifier message.
- FR-005: The UI no longer requires a manual proof-envelope paste for looked-up
  facts. Manual envelope verification may remain available only if it does not
  obscure the automatic lookup verdict.
- FR-006: Tests use a captured real `umpfs.plutimus.com` `/facts/:key` response
  with a non-empty `mpf_proof`; the original response verifies and a tampered
  proof rejects through the real bundled reactor.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- `flake.lock` shows the offchain input at `82dc3b9...` and no unrelated input
  bumps.
- A captured live `GET /tokens/:id/facts/:key` fixture verifies through
  `verify_fact_inclusion`.
- A tampered version of that same fixture returns `verify_error`.
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
