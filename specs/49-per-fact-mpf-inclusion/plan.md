# Plan

## Technical Shape

This ticket is a narrow WASM delegation pass over the existing facts lookup
surface. The current app decodes `/tokens/:id/facts/:key` down to only
`value`, and the UI exposes a manual proof-envelope textarea. The new flow must
preserve the raw response object and forward it unchanged to the verifier.

Relevant modules:

- `src/MPFS/Client.purs`: fetch/decode the fact response while preserving raw
  JSON.
- `src/App.purs`: lookup orchestration and automatic verification.
- `src/MPFS/App/Facts.purs`: lookup state transitions.
- `src/MPFS/App/View.purs`: lookup and verification labels.
- `src/MPFS/App/Verification.purs`: existing thin wrapper around
  `MPFS.Reactor.verifyEnvelope`.
- `test/Test/MPFS/VerifyE2ESpec.purs`: real reactor proof tests.
- `test/Test/MPFS/ClientSpec.purs` and `test/Test/FactsSpec.purs`: focused
  decode/state coverage.

The implementation must consume `MPFS.Reactor.verifyEnvelope` as-is. The only
envelope construction done in PureScript is JSON packaging around raw data:
`op`, `trusted_root`, `facts`, and `key`.

## Slice 1 - Repin Offchain Verify Reactor

One build/config commit updates the flake lock to the offchain revision that
contains `verify_fact_inclusion`.

Expected approach:

1. Run `nix flake lock --update-input cardano-mpfs-offchain`.
2. Confirm the locked revision is
   `82dc3b93c08374b068f3351a85e5e7311474728e`.
3. Review the lock diff: only `cardano-mpfs-offchain` and its follow graph may
   change; do not bump unrelated inputs.
4. Run `nix build --fallback --quiet --no-link .#wasm-mpfs-verify`, then
   `./gate.sh` if feasible.

Owned files:

- `flake.lock`

Forbidden scope:

- Any PureScript source, tests, package manifests, or reactor internals.

Focused command:

```sh
nix build --fallback --quiet --no-link .#wasm-mpfs-verify
```

Full gate:

```sh
./gate.sh
```

Commit:

```text
build(wasm): repin offchain for fact verifier

Tasks: T049-S1
```

## Slice 2 - Forward Lookup Response To WASM Verifier

One behavior-changing commit wires lookup, tests, and UI together so HEAD stays
bisect-safe.

Expected approach:

1. RED: add a captured real fixture from `umpfs.plutimus.com`, using token
   `98207724b0ea59b96c0eba16cb09e91da10f8bdc54ad36da4a2e40104a59a32b`, key
   `70616f6c696e6f`, and facts root
   `07e7e0b25afcd0684d5c086d173491975ee1f3296c89cd50ed28d963349a4461`.
   The fixture must contain a non-empty `fact.mpf_proof`.
2. RED: prove `verifyEnvelope` accepts the honest
   `verify_fact_inclusion` envelope and rejects the same raw response after
   tampering `fact.mpf_proof`.
3. RED: add focused client/state tests showing the lookup path preserves both
   the raw JSON response and the value, and that successful lookup can complete
   with a verification verdict.
4. GREEN: add the raw fact fetch/decode path in `MPFS.Client` without removing
   compatibility for value decoding.
5. GREEN: in `LookupFact`, obtain the selected token facts root from the
   current token state, or fetch `GET /tokens/:id` if the state has not been
   loaded, then build and submit the `verify_fact_inclusion` envelope.
6. GREEN: update the UI so lookup automatically reports `Verified` or rejected
   after the lookup; do not require a manual proof envelope for the normal fact
   lookup path.
7. Run focused tests, then `./gate.sh`.

Owned files:

- `src/MPFS/Client.purs`
- `src/App.purs`
- `src/MPFS/App/Facts.purs`
- `src/MPFS/App/View.purs`
- `src/MPFS/App/Verification.purs` only for a pure envelope helper if needed.
- `test/Test/MPFS/ClientSpec.purs`
- `test/Test/MPFS/VerifyE2ESpec.purs`
- `test/Test/FactsSpec.purs`
- `test/fixtures/real-umpfs-fact-inclusion.json`

Forbidden scope:

- `src/MPFS/Reactor.purs`
- `src/MPFS/Reactor.js`
- `src/bootstrap.js`
- `src/assets/*.wasm`
- `flake.lock`
- `flake.nix`, `spago.yaml`, `package*.json`
- Any MPF proof decoding or verification implementation in PureScript.

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
fix(facts): verify looked-up fact inclusion

Tasks: T049-S2
```

## Finalization

The ticket-orchestrator verifies each pair commit, reruns `./gate.sh`, amends
the matching `tasks.md` checkboxes into the accepted slice commit, pushes the
branch, updates the draft PR body with `Closes #49` and parent `#47`, and
reports `READY-FOR-REVIEW <sha>` via `/tmp/mpfs49/ticket/STATUS.md`.
