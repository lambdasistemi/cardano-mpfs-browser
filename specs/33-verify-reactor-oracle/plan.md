# Plan

## Scope

Deliver issue #33 in two ordered, bisect-safe implementation slices. The first
slice makes the pure verification reactor an explicit boundary separate from the
cage transaction reactor. The second slice adds the csmt-utxo second oracle and
renders its verdict in the Facts tab.

## Source Map

- Pure verify path:
  - `src/MPFS/App/Verification.purs`
  - `src/MPFS/Reactor.purs`
  - `src/MPFS/Reactor.js`
  - `src/bootstrap.js`
  - `test/Test/MPFS/ProofSpec.purs`
  - `test/Test/FactsSpec.purs`
- Cage transaction boundary:
  - `src/MPFS/Cage/Reactor.purs`
  - `src/MPFS/Cage/Reactor.js`
  - `src/MPFS/Cage/Wasm.purs`
  - `test/Test/MPFS/CageSpec.purs`
- App state and UI for the oracle:
  - `src/App.purs`
  - `src/MPFS/App/State.purs`
  - `src/MPFS/App/Facts.purs`
  - `src/MPFS/App/View.purs`
- HTTP and domain support:
  - `src/MPFS/Client.purs`
  - `src/MPFS/Client/Types.purs`
  - `src/MPFS/Types.purs`
  - new `src/MPFS/SecondOracle.purs`
  - new `src/MPFS/SecondOracle/Client.purs`
  - new `src/MPFS/SecondOracle/Verifier.purs`
  - matching FFI `.js` files only where WASM execution requires them
- Tests:
  - new `test/Test/SecondOracleSpec.purs`
  - extensions to existing app, client, and proof specs

## Architectural Decisions

- The verify reactor is the only boundary used for existing proof-envelope
  verification. Its PureScript and JavaScript names should say "verify" rather
  than "cage" so future write-flow code cannot accidentally call the wrong WASM.
- The cage transaction boundary remains the write-flow boundary. If the current
  reexport is wrong, S1 fixes it by adding/loading the cage reactor asset from
  the same `wasm-mpfs-verify` output and preserving the cage stdout parsers
  already used by write tests.
- The csmt-utxo verifier is neutral: consume the `mts:csmt-verify-wasm` artifact
  exposed through `cardano-mpfs-offchain`, and call its inclusion verifier from
  a thin FFI boundary. Do not implement trie/hash verification in PureScript.
- The csmt-utxo REST base URL defaults to `https://utxo-csmt.plutimus.com` and
  should be configurable in state/config the same way the MPFS base URL is.
- The oracle client pairs proofs to roots by exact `{slotNo, blockHash}`. A root
  missing for the proof chainpoint is a mismatch/error state, not a successful
  verification.
- The attested TxOut datum comparison reuses existing CBOR/Plutus decode helpers
  when possible. Any missing datum or undecodable facts root is surfaced as a
  typed oracle failure.

## Slice 1 - Dedicated Pure Verify Reactor Boundary

Rename and isolate the existing pure verification bridge:

- expose a verify-specific runner in `MPFS.Reactor` such as `runVerifyReactor`;
- seed `globalThis.runVerifyReactor` from `src/bootstrap.js`;
- keep `verifyEnvelope` parsing `verify_ok` and `verify_error`;
- stop `MPFS.Cage.Reactor` from reexporting the verify runner as its cage
  runner. If tx-building needs a separate cage bridge to keep existing write
  behavior green, add that bridge and asset preparation inside this slice;
- update focused proof/cage tests so a known verify verdict succeeds, a
  corrupted proof fails, and cage parser tests cannot pass by relying on the
  verify runner name.

This slice must not add the csmt-utxo client or UI.

## Slice 2 - csmt-utxo Second Oracle

Add the second oracle end to end:

- add the neutral csmt verifier WASM asset preparation and FFI boundary;
- add csmt-utxo client types and decoders for `/merkle-roots` and
  `/proof/:txId/:txIx`;
- derive or carry the selected token's current output reference and facts root
  from the existing token/facts state;
- run proof/root inclusion verification through the neutral WASM verifier;
- decode the attested TxOut datum and compare it with the MPFS facts root;
- store oracle state in the app model and render a "second-oracle verified" or
  mismatch indicator in the Facts tab;
- add unit tests for client decoding, proof/root matching, verifier verdict
  handling, comparison logic, and UI state.

If e2e proof requires a choice between live preprod and a mock/local service,
write a Q-file to the epic before changing the gate.

## Verification

Each slice follows RED -> GREEN through the driver/navigator pair. The focused
test command should be the smallest PureScript command that proves the slice,
followed by `./gate.sh`. The ticket-orchestrator reruns `./gate.sh` before
accepting and pushing each slice.

## Forbidden Scope For All Slices

- No edits under `/code/cardano-mpfs-offchain` or to the csmt-utxo service.
- No PureScript trie/hash verifier and no JavaScript crypto.
- No `@noble/*`, MUI, Emotion, React, or unrelated npm dependency additions.
- No flake input revision or PureScript registry bump without a Q-file and epic
  approval.
- No unrelated UI redesign, endpoint renaming, or write-flow behavior changes.
