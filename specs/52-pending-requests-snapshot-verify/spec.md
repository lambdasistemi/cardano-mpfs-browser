# Issue #52: Pending Requests Snapshot Verify

## P1 User Story

As an MPFS user, when I load the Facts tab for a token with pending requests,
the browser anchors the raw `GET /tokens/:id/requests` snapshot against the
independent UTxO-CSMT oracle, forwards the unchanged response to the bundled
Haskell WASM verifier, and shows `Pending requests: Verified` only when the
reactor returns `verify_ok`. If the request set or anchoring data is tampered,
the app shows rejected.

## Context

This is the final delegation child of epic #47. The browser must not implement
pending-request proof or request-address-prefix verification in PureScript.
The branch is pinned to `cardano-mpfs-offchain`
`82dc3b93c08374b068f3351a85e5e7311474728e`, whose verifier reactor dispatches
`verify_snapshot` and `verify_requests` to the same `verifyTokenRequests`
implementation.

The reactor contract at that revision is:

```json
{
  "op": "verify_snapshot",
  "trusted_root": "<independent UTxO-CSMT root at requests.snapshot.chainpoint.slot>",
  "facts": "<raw /tokens/:id/requests response object>",
  "cage_config": "<browser cage config>",
  "token_id": "<token id hex from the request path>"
}
```

`cage_config` and `token_id` are required because the Haskell verifier derives
the token-specific request address prefix locally before checking
`requests.request_set` completeness.

The trusted root is not taken on trust from `/tokens/:id/requests`. The browser
reads `snapshot.chainpoint.slot`, fetches independent UTxO-CSMT merkle roots via
`MPFS.SecondOracle.Client.getMerkleRoots`, requires the matching slot root to
equal `snapshot.utxo_root`, and passes that independently anchored root to the
WASM op.

The current live positive token checked during planning is
`976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6`, whose
`/requests` response has 6 request-set entries at slot `127145808` with UTxO
root `ab40ae6f3f0076950bed10ed11b69d69ffb57fcd185f2ecc1eb9aa3e067c7bfc`.
The second oracle currently reports the same root for that slot.

## Functional Requirements

- FR-001: The client can fetch `GET /tokens/:id/requests` as raw parsed JSON
  while preserving the existing decoded `Array PendingRequest` for app state.
- FR-002: Facts loading reads the raw requests response snapshot slot, fetches
  independent UTxO-CSMT roots, and rejects the pending-requests verdict if no
  matching root exists or if it does not equal `snapshot.utxo_root`.
- FR-003: Facts loading builds a `verify_snapshot` envelope with the
  independent trusted root, raw `/tokens/:id/requests` response, browser cage
  config, and selected token id.
- FR-004: Facts loading calls `MPFS.Reactor.verifyEnvelope`; `verify_ok` maps to
  `Verified`, while `verify_error` or anchoring errors map to rejected with the
  verifier or anchoring message available in state/UI.
- FR-005: The Facts tab displays a `Pending requests: Verified` / rejected
  indicator distinct from the existing load status, facts-set verifier,
  per-fact lookup verifier, and second-oracle indicator.
- FR-006: Tests use a captured real `umpfs.plutimus.com`
  `/tokens/:id/requests` response with non-empty `request_set.entries`; the
  honest response verifies and a tampered response rejects through the real
  bundled reactor.
- FR-007: Tests prove that a mismatched independent UTxO-CSMT root fails before
  the app can report `Verified`.
- FR-008: No PureScript request-set proof traversal, request-prefix derivation,
  MPF/CSMT verification implementation, or reactor internals are introduced.

## Acceptance Criteria

- `./gate.sh` passes at HEAD.
- A captured real non-empty `GET /tokens/:id/requests` fixture verifies through
  `verify_snapshot` after independent UTxO-CSMT root anchoring.
- A tampered version of that same fixture returns `verify_error`.
- A mismatched independent UTxO-CSMT root produces a rejected/not-anchored
  outcome.
- Loading facts in the running app shows `Pending requests: Verified` for the
  live positive path and rejected for the walked negative/tampered path.
- The PR links `Closes #52` and parent `#47`.

## Non-Goals

- Do not edit `src/MPFS/Reactor.purs`, `src/MPFS/Reactor.js`, the Haskell
  offchain repository, or `flake.lock`.
- Do not decode, reassemble, or verify the request-set proof in PureScript.
- Do not use empty fixtures as proof; CI must exercise real non-empty captured
  data, with live walking left to the epic owner.
