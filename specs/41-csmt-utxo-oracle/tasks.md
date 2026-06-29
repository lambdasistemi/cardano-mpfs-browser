# Tasks

## Slice 0 - Planning And Gate

- [X] T041-S0 Write the issue spec, implementation plan, task breakdown, and
  ticket gate.
- [X] T041-S0 Open a draft PR linked to `Closes #41` and parent `#34`.

## Slice 1 - Bundle And Verify Primitive

- [X] T041-S1 Repin `cardano-mpfs-offchain` in `flake.lock` to revision
  `a20656e`, with no unrelated input bumps.
- [X] T041-S1 Extend `just prepare-wasm` to assert and install
  `csmt-verify-wasm.wasm` from `.#wasm-mpfs-verify`.
- [X] T041-S1 Add the binary-stdin `csmt-verify-wasm` JS runner and PureScript
  wrapper under `src/MPFS/SecondOracle/`.
- [X] T041-S1 Add RED/GREEN coverage for a captured real root/proof verifying
  true and a tampered variant verifying false.
- [X] T041-S1 Run the focused verifier tests and `./gate.sh`, then commit the
  slice.

## Slice 2 - csmt-utxo REST Client

- [ ] T041-S2 Add csmt-utxo response types for merkle roots, proof responses,
  chainpoints, output references, and attested TxOut payloads.
- [ ] T041-S2 Add a REST client for `/merkle-roots` and
  `/proof/:txId/:txIx`, defaulting to `https://utxo-csmt.plutimus.com` where
  appropriate but keeping tests fixture-driven.
- [ ] T041-S2 Add valid and malformed fixture decode tests for both endpoints.
- [ ] T041-S2 Run the focused client tests and `./gate.sh`, then commit the
  slice.

## Slice 3 - Cross-Check Verdict

- [ ] T041-S3 Add second-oracle verdict logic for outputRef -> proof/root ->
  WASM inclusion check -> attested datum facts-root comparison.
- [ ] T041-S3 Decode or extract the MPFS facts root from the attested `txOut`
  datum using existing CBOR/Plutus-data helpers where possible.
- [ ] T041-S3 Cover verified, mismatch, unavailable, missing-root, and verifier
  false paths with deterministic fixtures.
- [ ] T041-S3 Escalate a Q-file if the selected token outputRef or stable
  MPFS-token fixture is not available from current project artifacts.
- [ ] T041-S3 Run the focused verdict tests and `./gate.sh`, then commit the
  slice.

## Slice 4 - UI Wiring

- [ ] T041-S4 Extend app state/actions with a second-oracle status and reset
  behavior on token/facts changes.
- [ ] T041-S4 Run the second-oracle check from the Facts load flow when the
  selected token outputRef and root are available.
- [ ] T041-S4 Render verified, mismatch, and unavailable/failure indicators in
  the Facts panel without changing unrelated layout.
- [ ] T041-S4 Add focused app/view coverage or a documented frontend smoke for
  the new indicator.
- [ ] T041-S4 Run the focused UI tests and `./gate.sh`, then commit the slice.

## Orchestrator Finalization

- [ ] T041-F1 Verify all slice commits and task amendments, update draft PR
  metadata with `Closes #41`, parent `#34`, and the live csmt-utxo smoke
  follow-up, run the final gate, and report `READY-FOR-REVIEW <sha>` to the
  epic via STATUS.md.
