# Plan

## Technical Shape

This ticket mirrors the trusted-root anchoring from issues #50 and #51, but
applies it to the raw `GET /tokens/:id/requests` response. The browser fetches
the requests endpoint once as raw JSON, decodes the existing pending-request
rows for UI state from the same body, independently anchors the response
snapshot root, and calls the WASM verifier through `MPFS.Reactor.verifyEnvelope`.

Relevant modules:

- `src/MPFS/Client.purs`: raw `/tokens/:id/requests` fetch/decode plus
  compatibility with existing pending-request decoding.
- `src/App.purs`: facts-load orchestration and independent root anchoring for
  the requests response.
- `src/MPFS/App/Facts.purs`: pending-requests verification state transitions.
- `src/MPFS/App/State.purs`: state field for the pending-requests verdict.
- `src/MPFS/App/View.purs`: Facts tab indicator and label.
- `src/MPFS/App/Verification.purs`: pure JSON envelope helper for
  `verify_snapshot`.
- `test/Test/MPFS/ClientSpec.purs`, `test/Test/FactsSpec.purs`, and
  `test/Test/MPFS/ProofSpec.purs`: focused decode/state/verifier coverage.
- `test/fixtures/real-umpfs-requests.json`: captured non-empty real requests
  response.

The implementation must consume `MPFS.Reactor.verifyEnvelope` as-is. PureScript
may only preserve raw JSON and package it into the verifier envelope; it must
not implement or interpret request-set proof semantics.

## Reactor Contract

The repinned offchain source at
`/nix/store/vk46clfwd9gjf6qq8w47hxnwnrbn161k-source/cardano-mpfs-verify/lib/Cardano/MPFS/Client/Verify/Reactor.hs`
dispatches both `verify_snapshot` and `verify_requests` to
`verifyTokenRequests`. Use `verify_snapshot` for the browser-facing envelope:

```json
{
  "op": "verify_snapshot",
  "trusted_root": "<independent UTxO-CSMT root>",
  "facts": "<raw /tokens/:id/requests response object>",
  "cage_config": "<browser cage config>",
  "token_id": "<selected token id hex>"
}
```

`cage_config` is the same `AppConfig.defaultCageConfig` shape already used for
`verify_tokens`. The token id is the selected token path segment; the response
body does not repeat it.

## Slice 1 - Forward Requests Response To WASM Verifier

One behavior-changing commit wires client, app state, UI, and tests together.

Expected approach:

1. RED: refresh `test/fixtures/real-umpfs-requests.json` from
   `https://umpfs.plutimus.com/tokens/976821dbd0922f93cda689da92a6faf1894c8151bc86d6c8f725ec089aaacbc6/requests`
   or another real token with a non-empty `request_set.entries`. During
   planning that live response had 6 entries at slot `127145808` and UTxO root
   `ab40ae6f3f0076950bed10ed11b69d69ffb57fcd185f2ecc1eb9aa3e067c7bfc`.
2. RED: prove an honest `verify_snapshot` envelope returns `verify_ok` when
   `trusted_root` is the independently anchored UTxO-CSMT root for the fixture
   slot, and a tampered response returns `verify_error`.
3. RED: prove a mismatched independent root fails as not anchored before trusted
   verification succeeds.
4. RED: add focused client/state/view tests for raw requests response
   preservation and the `Pending requests: Verified` / rejected labels.
5. GREEN: add a raw requests fetch path in `MPFS.Client` without removing the
   existing `getTokenRequests` decoded-list API.
6. GREEN: in `LoadFacts`, fetch raw requests, derive displayed pending requests
   from the raw response, independently anchor `snapshot.utxo_root` via
   `SecondOracle.Client.getMerkleRoots`, and call `verify_snapshot` with
   `AppConfig.defaultCageConfig` and the selected token id.
7. GREEN: update facts state transitions and Facts tab UI so success displays
   `Pending requests: Verified`; verifier or anchoring failures display
   rejected.
8. Run focused tests, then `./gate.sh`.

Owned files:

- `src/MPFS/Client.purs`
- `src/App.purs`
- `src/MPFS/App/Facts.purs`
- `src/MPFS/App/State.purs`
- `src/MPFS/App/View.purs`
- `src/MPFS/App/Verification.purs`
- `test/Test/MPFS/ClientSpec.purs`
- `test/Test/FactsSpec.purs`
- `test/Test/MPFS/ProofSpec.purs`
- `test/fixtures/real-umpfs-requests.json`

Forbidden scope:

- `src/MPFS/Reactor.purs`
- `src/MPFS/Reactor.js`
- `src/bootstrap.js`
- `src/assets/*.wasm`
- `flake.lock`
- `flake.nix`, `spago.yaml`, `package*.json`
- Any request-set proof decoding, request-address-prefix derivation, or
  verification implementation in PureScript.

Focused commands:

```sh
nix develop --quiet --command spago test --main Test.Main
nix develop --quiet --command just lint
```

Full gate:

```sh
./gate.sh
```

Commit:

```text
fix(requests): verify pending request snapshot

Tasks: T052-S1
```

## Finalization

The ticket-orchestrator verifies the pair commit, reruns `./gate.sh`, amends
the matching `tasks.md` checkboxes into the accepted slice commit, pushes the
branch, updates the draft PR body with `Closes #52` and parent `#47`, and
reports `READY-FOR-REVIEW <sha>` via `/tmp/mpfs52/ticket/STATUS.md`.
