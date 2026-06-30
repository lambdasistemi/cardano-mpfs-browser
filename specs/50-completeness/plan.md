# Plan

## Technical Shape

This ticket mirrors the trusted-root anchoring from issue #49, but applies it
to the whole token registry response. The browser fetches `/tokens` once,
preserves the raw JSON object for the verifier, decodes the existing token-id
list for UI state, independently anchors the response snapshot root, and calls
the WASM verifier through `MPFS.Reactor.verifyEnvelope`.

Relevant modules:

- `src/MPFS/Client.purs`: raw `/tokens` fetch/decode plus compatibility with
  existing token id decoding.
- `src/App.purs`: token-load orchestration and independent root anchoring.
- `src/MPFS/App/Tokens.purs`: token completeness state transitions.
- `src/MPFS/App/State.purs`: state field for the token list completeness
  verdict.
- `src/MPFS/App/View.purs`: Tokens tab indicator and label.
- `src/MPFS/App/Verification.purs`: pure JSON envelope helper for
  `verify_tokens`, if useful.
- `test/Test/MPFS/ClientSpec.purs`, `test/Test/TokensSpec.purs`,
  `test/Test/FactsSpec.purs`, and `test/Test/MPFS/ProofSpec.purs`: focused
  decode/state/verifier coverage.

The implementation must consume `MPFS.Reactor.verifyEnvelope` as-is. PureScript
may only package JSON fields into the verifier envelope; it must not implement
or interpret completeness proof semantics.

## Slice 1 - Forward Tokens Response To WASM Verifier

One behavior-changing commit wires client, app state, UI, and tests together.
The branch is already repinned to the offchain revision that contains the
`verify_tokens` op.

Expected approach:

1. RED: add a real captured `/tokens` fixture from `umpfs.plutimus.com` with
   non-empty `tokens.entries` and a non-empty `tokens.completeness_proof`.
2. RED: prove an honest `verify_tokens` envelope returns `verify_ok` when
   `trusted_root` is the independently anchored UTxO-CSMT root for the fixture
   slot, and a tampered response returns `verify_error`.
3. RED: prove a mismatched independent root fails as not anchored before trusted
   verification succeeds.
4. RED: add focused client/state/view tests for raw token response preservation
   and the `complete` / `incomplete` status labels.
5. GREEN: add a raw token fetch path in `MPFS.Client` without removing the
   existing `getTokens` decoded-list API.
6. GREEN: in `LoadTokens`, fetch raw tokens, derive token ids from the raw
   response, independently anchor `snapshot.utxo_root` via
   `SecondOracle.Client.getMerkleRoots`, and call `verify_tokens` with
   `AppConfig.defaultCageConfig`.
7. GREEN: update token state transitions and Tokens tab UI so success displays
   `complete`; verifier or anchoring failures display `incomplete`.
8. Run focused tests, then `./gate.sh`.

Owned files:

- `src/MPFS/Client.purs`
- `src/App.purs`
- `src/MPFS/App/Tokens.purs`
- `src/MPFS/App/View.purs`
- `src/MPFS/App/State.purs`
- `src/MPFS/App/Verification.purs`
- `test/Test/MPFS/ClientSpec.purs`
- `test/Test/TokensSpec.purs`
- `test/Test/FactsSpec.purs`
- `test/Test/MPFS/ProofSpec.purs`
- `test/fixtures/real-umpfs-tokens.json`

Forbidden scope:

- `src/MPFS/Reactor.purs`
- `src/MPFS/Reactor.js`
- `src/bootstrap.js`
- `src/assets/*.wasm`
- `flake.lock`
- `flake.nix`, `spago.yaml`, `package*.json`
- Any completeness proof decoding or verification implementation in
  PureScript.

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
fix(tokens): verify token list completeness

Tasks: T050-S1
```

## Finalization

The ticket-orchestrator verifies the pair commit, reruns `./gate.sh`, amends
the matching `tasks.md` checkboxes into the accepted slice commit, pushes the
branch, updates the draft PR body with `Closes #50` and parent `#47`, and
reports `READY-FOR-REVIEW <sha>` via `/tmp/mpfs50/ticket/STATUS.md`.
