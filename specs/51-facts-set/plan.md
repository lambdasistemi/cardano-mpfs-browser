# Plan

## Technical Shape

This ticket mirrors the trusted-root anchoring from issues #49 and #50, but
applies it to the full `GET /tokens/:id/facts` response. The browser fetches
the facts endpoint once, preserves the raw JSON object for the verifier, decodes
the existing facts array for UI state, independently anchors the response
snapshot root, and calls the WASM verifier through `MPFS.Reactor.verifyEnvelope`.

Relevant modules:

- `src/MPFS/Client.purs`: raw `/tokens/:id/facts` fetch/decode plus
  compatibility with existing facts-array decoding.
- `src/App.purs`: facts-load orchestration and independent root anchoring.
- `src/MPFS/App/Facts.purs`: facts-set verification state transitions.
- `src/MPFS/App/State.purs`: state field for the facts-set verdict.
- `src/MPFS/App/View.purs`: Facts tab indicator and label.
- `src/MPFS/App/Verification.purs`: pure JSON envelope helper for
  `verify_facts`, if useful.
- `test/Test/MPFS/ClientSpec.purs`, `test/Test/FactsSpec.purs`, and
  `test/Test/MPFS/ProofSpec.purs`: focused decode/state/verifier coverage.
- `test/fixtures/real-umpfs-facts.json`: captured non-empty real facts-set
  response.

The implementation must consume `MPFS.Reactor.verifyEnvelope` as-is. PureScript
may only package JSON fields into the verifier envelope; it must not implement
or interpret facts-set proof semantics.

## Slice 1 - Forward Facts Response To WASM Verifier

One behavior-changing commit wires client, app state, UI, and tests together.
The branch is already repinned to the offchain revision that contains the
`verify_facts` op.

Expected approach:

1. RED: refresh `test/fixtures/real-umpfs-facts.json` from
   `https://umpfs.plutimus.com/tokens/98207724b0ea59b96c0eba16cb09e91da10f8bdc54ad36da4a2e40104a59a32b/facts`
   or another real token with a non-empty `facts` array. The current live
   response has two facts at slot `127144070` and UTxO root
   `139aa8a7aabeaf55a8babe9df8b5f710cb45a60a0478cba6b11fb4f57e921ba7`.
2. RED: prove an honest `verify_facts` envelope returns `verify_ok` when
   `trusted_root` is the independently anchored UTxO-CSMT root for the fixture
   slot, and a tampered response returns `verify_error`.
3. RED: prove a mismatched independent root fails as not anchored before trusted
   verification succeeds.
4. RED: add focused client/state/view tests for raw facts response preservation
   and the `Facts set: Verified` / rejected labels.
5. GREEN: add a raw facts fetch path in `MPFS.Client` without removing the
   existing `getTokenFacts` decoded-list API.
6. GREEN: in `LoadFacts`, fetch raw facts, derive displayed facts from the raw
   response, independently anchor `snapshot.utxo_root` via
   `SecondOracle.Client.getMerkleRoots`, and call `verify_facts`.
7. GREEN: update facts state transitions and Facts tab UI so success displays
   `Facts set: Verified`; verifier or anchoring failures display rejected.
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
- `test/fixtures/real-umpfs-facts.json`

Forbidden scope:

- `src/MPFS/Reactor.purs`
- `src/MPFS/Reactor.js`
- `src/bootstrap.js`
- `src/assets/*.wasm`
- `flake.lock`
- `flake.nix`, `spago.yaml`, `package*.json`
- Any facts-set proof decoding or verification implementation in PureScript.

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
fix(facts): verify full facts set

Tasks: T051-S1
```

## Finalization

The ticket-orchestrator verifies the pair commit, reruns `./gate.sh`, amends
the matching `tasks.md` checkboxes into the accepted slice commit, pushes the
branch, updates the draft PR body with `Closes #51` and parent `#47`, and
reports `READY-FOR-REVIEW <sha>` via `/tmp/mpfs51/ticket/STATUS.md`.
