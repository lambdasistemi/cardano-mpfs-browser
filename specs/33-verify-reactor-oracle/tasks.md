# Tasks

## Slice 1 - Dedicated Pure Verify Reactor Boundary

- [ ] T033-S1 Rename/expose the pure verifier bridge so proof verification calls
  a verify-specific runner backed by `mpfs-verify-reactor.wasm`, and update
  `src/bootstrap.js`, `src/MPFS/Reactor.{purs,js}`,
  `src/MPFS/App/Verification.purs`, and focused proof tests accordingly.
- [ ] T033-S1 Separate the cage transaction reactor boundary from the verify
  bridge in `src/MPFS/Cage/Reactor.{purs,js}` and related asset preparation,
  preserving write-flow parser behavior and keeping cage tests green.
- [ ] T033-S1 Add RED/GREEN proof coverage for `verify_ok` and `verify_error`
  through the dedicated verify boundary, then run `./gate.sh`.

## Slice 2 - csmt-utxo Second Oracle

- [ ] T033-S2 Add the neutral csmt verifier WASM asset and thin FFI/PureScript
  boundary for inclusion proof verification without adding JavaScript crypto.
- [ ] T033-S2 Add csmt-utxo REST client types, decoders, and chainpoint matching
  for `/merkle-roots` and `/proof/:txId/:txIx`.
- [ ] T033-S2 Implement second-oracle state logic: selected token outputRef,
  proof/root verification, attested TxOut datum decode, facts-root comparison,
  verified/mismatch/error status, and reset behavior on token/facts changes.
- [ ] T033-S2 Render the second-oracle indicator and action in the Facts tab and
  add focused unit tests for decode, verify, comparison, and UI state paths.
- [ ] T033-S2 Run the focused PureScript proof and `./gate.sh`.

## Orchestrator Finalization

- [ ] T033-F1 Verify each slice commit and task amendments, update draft PR
  metadata with `Closes #33` and parent `#34`, run the final gate, and report
  `READY-FOR-REVIEW <sha>` to the epic.
