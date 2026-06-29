# Plan

## Scope

Deliver issue #41 in four bisect-safe implementation slices plus an
orchestrator-owned planning/gate slice. The feature adds an independently
verified csmt-utxo inclusion check for the selected MPFS token anchor and shows
the resulting second-oracle verdict in the Halogen UI.

## Source Map

- WASM bundling and runner:
  - `flake.lock`
  - `justfile`
  - `src/bootstrap.js`
  - `src/MPFS/SecondOracle/CsmtVerify.js`
  - `src/MPFS/SecondOracle/CsmtVerify.purs`
- csmt-utxo client and types:
  - `src/MPFS/SecondOracle/Client.purs`
  - `src/MPFS/SecondOracle/Types.purs`
- verdict logic:
  - `src/MPFS/SecondOracle.purs`
  - `src/MPFS/Tx/Cbor.*`
  - `src/MPFS/Tx/PlutusData.purs`
  - `src/MPFS/Client.Types` only if the selected token output reference is
    available in an existing MPFS API response but not yet typed
- app wiring:
  - `src/MPFS/App/State.purs`
  - `src/MPFS/App/Facts.purs`
  - `src/App.purs`
  - `src/MPFS/App/View.purs`
- tests and fixtures:
  - `test/Test/MPFS/SecondOracle*.purs`
  - `test/fixtures/*`
  - `test/Test/Main.purs`

## Design

`csmt-verify-wasm` is loaded as its own verifier path. Do not reuse
`MPFS.Reactor.js`: that runner encodes text JSON envelopes and parses stdout,
while the neutral CSMT verifier requires binary stdin and communicates only by
exit code. The new JS runner should follow the same WASI shim shape but pass an
`OpenFile` containing a `Uint8Array` of opcode, root bytes, and proof bytes.

The csmt-utxo client is a small HTTP/JSON layer over:

```text
GET https://utxo-csmt.plutimus.com/merkle-roots
GET https://utxo-csmt.plutimus.com/proof/:txId/:txIx
```

The verdict logic chooses the root entry whose `{slotNo, blockHash}` matches the
proof response, verifies inclusion with opcode `0`, then compares the attested
TxOut datum's MPFS facts root with the root reported by the MPFS API for the
selected token.

If a captured real proof from the deployed service does not verify against the
bundled WASM at the pinned offchain revision, stop and escalate a determinism
mismatch Q-file. If the current MPFS API does not expose a selected token
output reference or stable fixture from which S3 can perform the token-anchor
cross-check, stop and escalate a fixture/API Q-file.

## Slice 1 - Bundle And Verify Primitive

- Repin only the `cardano-mpfs-offchain` flake input and its follows to
  revision `a20656e`.
- Extend `just prepare-wasm` to copy `csmt-verify-wasm.wasm` from
  `.#wasm-mpfs-verify`.
- Add `src/MPFS/SecondOracle/CsmtVerify.js` and `.purs` with
  `verifyInclusion :: String -> String -> Aff Boolean`.
- Add focused tests using one captured real root/proof fixture for `true` and a
  tampered byte for `false`.
- Gate the flake lock diff: no incidental input bumps.

## Slice 2 - csmt-utxo REST Client

- Add `src/MPFS/SecondOracle/Types.purs` and `Client.purs`.
- Decode `/merkle-roots` entries and `/proof/:txId/:txIx` responses.
- Preserve `proof` as hex CBOR and `txOut` as a structured or raw JSON value
  sufficient for the next slice.
- Test captured valid fixtures and malformed decode failures.

## Slice 3 - Cross-Check Verdict

- Add `src/MPFS/SecondOracle.purs` and verdict types.
- For an output reference, fetch proof, find the matching chainpoint root, run
  `verifyInclusion`, decode the attested TxOut datum, and compare to the MPFS
  facts root.
- Cover verified, mismatch, verifier false, missing root, malformed datum, and
  client-unavailable verdicts with fixtures.
- Escalate if the selected-token output reference cannot be derived from the
  existing API or fixture set.

## Slice 4 - UI Wiring

- Extend app state with the second-oracle remote/verdict status.
- Trigger the check after selected token facts/root load when an output
  reference is available, and reset the status when token/facts inputs change.
- Render the status in the Facts panel next to the trusted root and existing
  verification status.
- Add focused app/view tests or documented frontend smoke if the existing test
  harness cannot observe the DOM state directly.

## Verification

Each implementation slice follows RED -> GREEN through the driver/navigator
pair. The ticket orchestrator reruns `./gate.sh` before accepting each slice.

Final gate:

```sh
./gate.sh
```

Live csmt-utxo smoke against `https://utxo-csmt.plutimus.com` is not part of CI;
record the operator follow-up in PR metadata.

## Forbidden Scope

- No JavaScript or PureScript cryptographic verifier.
- No edits to `src/MPFS/Reactor.*`, `src/MPFS/Cage*`, `flake.nix`, package
  manifests, the offchain repository, or the csmt-utxo service.
- No live-service dependency in default `just ci` or `./gate.sh`.
