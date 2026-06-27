# Plan

## Scope

Deliver issue #37 in one implementation slice: an e2e PureScript spec that uses
the existing devnet harness and the existing verify reactor boundary to prove
both the honest `verify_ok` path and a tampered `verify_error` path against real
same-revision facts.

## Source Map

- Existing e2e harness:
  - `justfile`
  - `test/Test/MPFS/ClientSpec.purs`
  - `test/Test/Main.purs`
- Existing verify boundary:
  - `src/MPFS/Reactor.purs`
  - `src/MPFS/Reactor.js`
  - `test/Test/MPFS/ProofSpec.purs`
- Candidate client support:
  - `src/MPFS/Client.purs`
  - `src/MPFS/Client/Types.purs`
- New test:
  - `test/Test/MPFS/VerifyE2ESpec.purs`

## Design

The new spec is registered under the same `MPFS_BASE_URL` guard as
`ClientSpec`, so ordinary `spago test` remains a unit run while `just e2e`
activates live-server specs.

The spec should fetch a same-revision facts envelope from the devnet server.
Prefer existing `MPFS.Client` methods if they expose enough data. If the typed
client only exposes decoded summaries, add the smallest read helper needed to
obtain the raw JSON envelope from the existing `/facts/boot` or token facts
endpoint. The trusted root comes from `getTrustedRoot` or the response snapshot's
`utxo_root`, whichever matches the fetched envelope.

The verification envelope passed to `verifyEnvelope` has the reactor shape:

```json
{"op":"boot","trusted_root":"<root>","facts":<facts-json>}
```

The tampered assertion must mutate data from the live envelope, not substitute a
static fixture. Flipping a proof/value byte or otherwise corrupting a verified
field is acceptable as long as the reactor returns `Left _` for the mutated
envelope.

## Slice 1 - Honest Verify E2E

- Add `test/Test/MPFS/VerifyE2ESpec.purs`.
- Register it in `test/Test/Main.purs` only when `MPFS_BASE_URL` is present.
- Add a small `MPFS.Client` helper only if the live boot facts JSON cannot be
  obtained through existing methods.
- Keep all verification routed through `MPFS.Reactor.verifyEnvelope`.
- Do not modify `MPFS.Reactor*`, `src/MPFS/Cage*`, package manifests, flake
  inputs, or static fixture files.

## Verification

The driver follows RED -> GREEN:

1. RED: add the e2e spec/registration and run the e2e harness to observe the
   missing helper or failing assertion.
2. GREEN: implement the minimal fetch/envelope/tamper logic and rerun the e2e
   harness to observe honest `Right unit` and tampered `Left _`.
3. Run `./gate.sh`.

The ticket-orchestrator reruns `./gate.sh` before accepting the slice.

## Forbidden Scope

- No static honest proof fixture.
- No JavaScript crypto, PureScript trie/hash verification, npm dependency
  changes, or flake input bumps.
- No edits under `/code/cardano-mpfs-offchain`.
- No UI redesign or unrelated app behavior changes.
